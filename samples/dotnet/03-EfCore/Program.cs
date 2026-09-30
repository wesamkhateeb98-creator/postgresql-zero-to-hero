// EF Core + Npgsql provider — LINQ, change tracking, migrations, Postgres-specific types.
// Run:  dotnet run --project 03-EfCore
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

var connectionString = Environment.GetEnvironmentVariable("SHOP_DB")
    ?? "Host=localhost;Port=5432;Database=shop;Username=app;Password=change_me_app";

var options = new DbContextOptionsBuilder<ShopContext>()
    .UseNpgsql(connectionString, npgsql => npgsql.EnableRetryOnFailure(maxRetryCount: 3))
    .UseSnakeCaseNamingConvention()
    .LogTo(Console.WriteLine, LogLevel.Information)   // prints every SQL statement
    .EnableSensitiveDataLogging()                     // shows parameter values — dev only
    .Options;

// No database needed: print the DDL EF Core expects and the SQL of a few queries.
//   dotnet run --project 03-EfCore -- --sql-only
if (args.Contains("--sql-only"))
{
    await using var dry = new ShopContext(options);
    Console.WriteLine(dry.Database.GenerateCreateScript());
    Console.WriteLine("-- orders of user 42 (projection):");
    Console.WriteLine(dry.Orders.AsNoTracking().Where(o => o.UserId == 42).OrderByDescending(o => o.CreatedAt)
        .Select(o => new { o.Id, o.Qty, Product = o.Product!.Name }).Take(5).ToQueryString());
    Console.WriteLine("\n-- red products (jsonb):");
    Console.WriteLine(dry.Products.Where(p => p.Attrs.Color == "red").ToQueryString());
    Console.WriteLine("\n-- products by ids (array):");
    long[] dryIds = [1, 2, 3];
    Console.WriteLine(dry.Products.Where(p => dryIds.Contains(p.Id)).Select(p => p.Name).ToQueryString());
    return;
}

// Compiled query: LINQ -> SQL translation is done once, not per call.
var ordersOfUser = EF.CompileAsyncQuery((ShopContext db, long userId) =>
    db.Orders.AsNoTracking()
      .Where(o => o.UserId == userId)
      .OrderByDescending(o => o.CreatedAt)
      .Take(5));

await using (var db = new ShopContext(options))
{
    // 1. Projection + AsNoTracking: read-only, only the needed columns
    var recent = await db.Orders.AsNoTracking()
        .Where(o => o.UserId == 42)
        .OrderByDescending(o => o.CreatedAt)
        .Select(o => new { o.Id, o.Qty, Product = o.Product!.Name })
        .Take(5)
        .ToListAsync();
    Console.WriteLine($"== projection\n{string.Join("\n", recent)}\n");

    // 2. Show the SQL without running it
    var query = db.Users.Where(u => u.Country == "JO").Include(u => u.Orders).AsSplitQuery();
    Console.WriteLine($"== ToQueryString (split query, first statement)\n{query.ToQueryString()}\n");

    // 3. jsonb: LINQ over the owned JSON type -> attrs ->> 'color'
    var red = await db.Products.CountAsync(p => p.Attrs.Color == "red");
    Console.WriteLine($"== jsonb\nred products: {red}\n");

    // 4. Arrays: Contains on a .NET array -> = ANY(@ids)
    long[] ids = [1, 2, 3];
    var names = await db.Products.Where(p => ids.Contains(p.Id)).Select(p => p.Name).ToListAsync();
    Console.WriteLine($"== arrays\n{string.Join(", ", names)}\n");

    // 5. Raw SQL: interpolation becomes parameters (safe), and calling a PL/pgSQL function
    var category = "books";
    var top = await db.Database
        .SqlQuery<TopProduct>($"SELECT product_id, name, units FROM top_products({category}, 3)")
        .ToListAsync();
    Console.WriteLine($"== SqlQuery (function)\n{string.Join("\n", top)}\n");

    // 6. Compiled query
    var compiled = new List<Order>();
    await foreach (var o in ordersOfUser(db, 42)) compiled.Add(o);
    Console.WriteLine($"== compiled query\n{compiled.Count} orders\n");

    // 7. Bulk update without loading entities (one UPDATE statement), inside a rolled-back transaction.
    //    With EnableRetryOnFailure, a manual transaction MUST run inside the execution strategy,
    //    otherwise EF throws InvalidOperationException (the whole block is what gets retried).
    var strategy = db.Database.CreateExecutionStrategy();
    await strategy.ExecuteAsync(async () =>
    {
        await using var tx = await db.Database.BeginTransactionAsync();
        var affected = await db.Products
            .Where(p => p.Category == "toys")
            .ExecuteUpdateAsync(s => s.SetProperty(p => p.Stock, p => p.Stock + 1));
        Console.WriteLine($"== ExecuteUpdate\n{affected} rows updated — rolling back\n");
        await tx.RollbackAsync();
    });
}

// 8. Optimistic concurrency with xmin: two contexts edit the same row
await using (var first = new ShopContext(options))
await using (var second = new ShopContext(options))
{
    var a = await first.Products.SingleAsync(p => p.Id == 1);
    var b = await second.Products.SingleAsync(p => p.Id == 1);

    a.Stock += 1;
    await first.SaveChangesAsync();                   // xmin changes

    b.Stock += 1;
    try
    {
        await second.SaveChangesAsync();              // WHERE id = 1 AND xmin = <old> -> 0 rows
    }
    catch (DbUpdateConcurrencyException)
    {
        Console.WriteLine("== concurrency\nsecond save rejected: row changed since it was read\n");
    }

    a.Stock -= 1;                                     // undo the demo change
    await first.SaveChangesAsync();
}
