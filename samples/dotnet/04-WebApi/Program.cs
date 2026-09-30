// Minimal API wiring everything together: DI, Dapper + EF Core on one data source,
// retries, health checks, OpenTelemetry tracing.
// Run:  dotnet run --project 04-WebApi    → http://localhost:5175/products/1
using Dapper;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using OpenTelemetry.Trace;

var builder = WebApplication.CreateBuilder(args);
var connectionString = builder.Configuration.GetConnectionString("Shop")!;

// One pooled NpgsqlDataSource registered as a singleton (package Npgsql.DependencyInjection)
builder.Services.AddNpgsqlDataSource(connectionString);

// EF Core reuses the same data source (same pool)
builder.Services.AddDbContext<ShopContext>((sp, options) => options
    .UseNpgsql(sp.GetRequiredService<NpgsqlDataSource>(), npgsql => npgsql.EnableRetryOnFailure(3))
    .UseSnakeCaseNamingConvention());

builder.Services.AddHealthChecks().AddNpgSql(connectionString);

builder.Services.AddOpenTelemetry().WithTracing(tracing => tracing
    .AddAspNetCoreInstrumentation()
    .AddNpgsql()                      // one span per SQL command
    .AddConsoleExporter());

DefaultTypeMap.MatchNamesWithUnderscores = true;

var app = builder.Build();

// Dapper: hand-written SQL on a pooled connection
app.MapGet("/products/{id:long}", async (long id, NpgsqlDataSource db) =>
{
    await using var conn = await db.OpenConnectionAsync();
    var product = await conn.QuerySingleOrDefaultAsync<ProductDto>(
        "SELECT id, name, category, price, stock FROM products WHERE id = @id", new { id });
    return product is null ? Results.NotFound() : Results.Ok(product);
});

// EF Core: LINQ projection, no tracking
app.MapGet("/users/{id:long}/orders", async (long id, ShopContext db) =>
    await db.Orders.AsNoTracking()
        .Where(o => o.UserId == id)
        .OrderByDescending(o => o.CreatedAt)
        .Take(20)
        .Select(o => new { o.Id, o.Qty, o.Status, o.CreatedAt, Product = o.Product!.Name })
        .ToListAsync());

// Npgsql: atomic checkout + retry on serialization failure / deadlock
app.MapPost("/orders", async (CreateOrder req, NpgsqlDataSource db) =>
{
    for (var attempt = 1; ; attempt++)
    {
        try
        {
            await using var conn = await db.OpenConnectionAsync();
            await using var tx = await conn.BeginTransactionAsync();

            await using var stock = new NpgsqlCommand(
                "UPDATE products SET stock = stock - $2 WHERE id = $1 AND stock >= $2", conn, tx);
            stock.Parameters.Add(new NpgsqlParameter { Value = req.ProductId });
            stock.Parameters.Add(new NpgsqlParameter { Value = req.Qty });
            if (await stock.ExecuteNonQueryAsync() == 0)
                return Results.Conflict(new { error = "out of stock" });

            await using var insert = new NpgsqlCommand(
                "INSERT INTO orders (user_id, product_id, qty) VALUES ($1, $2, $3) RETURNING id", conn, tx);
            insert.Parameters.Add(new NpgsqlParameter { Value = req.UserId });
            insert.Parameters.Add(new NpgsqlParameter { Value = req.ProductId });
            insert.Parameters.Add(new NpgsqlParameter { Value = req.Qty });
            var orderId = (long)(await insert.ExecuteScalarAsync())!;

            await tx.CommitAsync();
            return Results.Created($"/orders/{orderId}", new { orderId });
        }
        catch (PostgresException e) when (attempt < 3 && e.SqlState is
            PostgresErrorCodes.SerializationFailure or PostgresErrorCodes.DeadlockDetected)
        {
            await Task.Delay(50 * attempt);                  // back off, then retry the whole transaction
        }
        catch (PostgresException e) when (e.SqlState == PostgresErrorCodes.ForeignKeyViolation)
        {
            return Results.BadRequest(new { error = "unknown user or product" });
        }
    }
});

app.MapHealthChecks("/health");

app.Run();

public sealed record ProductDto(long Id, string Name, string Category, decimal Price, int Stock);
public sealed record CreateOrder(long UserId, long ProductId, int Qty);

public sealed class ShopContext(DbContextOptions<ShopContext> options) : DbContext(options)
{
    public DbSet<Order> Orders => Set<Order>();
    public DbSet<Product> Products => Set<Product>();
}

public sealed class Product
{
    public long Id { get; set; }
    public string Name { get; set; } = "";
}

public sealed class Order
{
    public long Id { get; set; }
    public long UserId { get; set; }
    public long ProductId { get; set; }
    public int Qty { get; set; }
    public string Status { get; set; } = "paid";
    public DateTime CreatedAt { get; set; }
    public Product? Product { get; set; }
}
