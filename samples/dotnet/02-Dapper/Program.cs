// Dapper — a micro-ORM: you write the SQL, Dapper maps rows to objects.
// Run:  dotnet run --project 02-Dapper
using System.Data;
using System.Text.Json;
using Dapper;
using Npgsql;
using NpgsqlTypes;

var connectionString = Environment.GetEnvironmentVariable("SHOP_DB")
    ?? "Host=localhost;Port=5432;Database=shop;Username=app;Password=change_me_app";

DefaultTypeMap.MatchNamesWithUnderscores = true;              // created_at -> CreatedAt
SqlMapper.AddTypeHandler(new JsonbHandler<ProductAttrs>());   // jsonb <-> ProductAttrs

await using var dataSource = NpgsqlDataSource.Create(connectionString);
await using var conn = await dataSource.OpenConnectionAsync();

// 1. Query<T> — many rows
var books = await conn.QueryAsync<Product>(
    "SELECT id, name, category, price, stock, attrs FROM products WHERE category = @category ORDER BY price DESC LIMIT 5",
    new { category = "books" });
Console.WriteLine("== QueryAsync<Product>");
foreach (var p in books) Console.WriteLine($"{p.Id,5} {p.Name,-14} {p.Price,8}  {p.Attrs}");

// 2. Single row / scalar
var user = await conn.QuerySingleOrDefaultAsync<User>(
    "SELECT id, email, name, country, created_at FROM users WHERE id = @id", new { id = 42L });
var orderCount = await conn.ExecuteScalarAsync<long>(
    "SELECT count(*) FROM orders WHERE user_id = @userId", new { userId = 42L });
Console.WriteLine($"\n== single + scalar\n{user?.Email} ({user?.Country}) has {orderCount} orders");

// 3. Arrays: pass a .NET array and use = ANY(@ids)  (not IN @ids — that expands to many parameters)
var some = await conn.QueryAsync<Product>(
    "SELECT id, name, category, price, stock, attrs FROM products WHERE id = ANY(@ids)",
    new { ids = new long[] { 1, 2, 3 } });
Console.WriteLine($"\n== ANY(@ids)\n{string.Join(", ", some.Select(p => p.Name))}");

// 4. Multi-mapping: one row -> Order + Product
var orders = await conn.QueryAsync<Order, Product, Order>(
    """
    SELECT o.id, o.user_id, o.qty, o.status, o.created_at,
           p.id, p.name, p.category, p.price, p.stock, p.attrs
    FROM orders o JOIN products p ON p.id = o.product_id
    WHERE o.user_id = @userId
    ORDER BY o.created_at DESC
    LIMIT 5
    """,
    (order, product) => { order.Product = product; return order; },
    new { userId = 42L },
    splitOn: "id");
Console.WriteLine("\n== multi-mapping");
foreach (var o in orders) Console.WriteLine($"order {o.Id}: {o.Qty} × {o.Product?.Name} ({o.Status})");

// 5. Calling a PL/pgSQL function
var top = await conn.QueryAsync<TopProduct>(
    "SELECT product_id, name, units FROM top_products(@category, @limit)", new { category = "toys", limit = 3 });
Console.WriteLine($"\n== function\n{string.Join("\n", top)}");

// 6. Transaction
await using (var tx = await conn.BeginTransactionAsync())
{
    var updated = await conn.ExecuteAsync(
        "UPDATE products SET stock = stock - 1 WHERE id = @id AND stock > 0", new { id = 1L }, tx);
    var newId = await conn.ExecuteScalarAsync<long>(
        "INSERT INTO orders (user_id, product_id, qty) VALUES (@userId, @productId, 1) RETURNING id",
        new { userId = 42L, productId = 1L }, tx);
    Console.WriteLine($"\n== transaction\nupdated {updated} product, created order {newId} — rolling back");
    await tx.RollbackAsync();
}

public sealed class User
{
    public long Id { get; set; }
    public string Email { get; set; } = "";
    public string Name { get; set; } = "";
    public string Country { get; set; } = "";
    public DateTime CreatedAt { get; set; }
}

public sealed class Product
{
    public long Id { get; set; }
    public string Name { get; set; } = "";
    public string Category { get; set; } = "";
    public decimal Price { get; set; }
    public int Stock { get; set; }
    public ProductAttrs? Attrs { get; set; }
}

public sealed class Order
{
    public long Id { get; set; }
    public long UserId { get; set; }
    public int Qty { get; set; }
    public string Status { get; set; } = "";
    public DateTime CreatedAt { get; set; }
    public Product? Product { get; set; }
}

public sealed record ProductAttrs(string Color, int Rating);

public sealed class TopProduct
{
    public long ProductId { get; set; }
    public string Name { get; set; } = "";
    public long Units { get; set; }
    public override string ToString() => $"{ProductId,5} {Name,-14} units={Units}";
}

// Dapper doesn't know jsonb: tell it how to read and write it.
public sealed class JsonbHandler<T> : SqlMapper.TypeHandler<T>
{
    private static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web);

    public override T? Parse(object value) => JsonSerializer.Deserialize<T>((string)value, Options);

    public override void SetValue(IDbDataParameter parameter, T? value)
    {
        parameter.Value = JsonSerializer.Serialize(value, Options);
        ((NpgsqlParameter)parameter).NpgsqlDbType = NpgsqlDbType.Jsonb;
    }
}
