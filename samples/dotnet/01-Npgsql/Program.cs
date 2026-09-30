// Npgsql — the ADO.NET driver every other .NET option is built on.
// Run:  dotnet run --project 01-Npgsql        (needs the repo's Postgres: docker compose up -d)
using System.Diagnostics;
using System.Text.Json;
using System.Text.Json.Serialization;
using Npgsql;
using NpgsqlTypes;

var connectionString = Environment.GetEnvironmentVariable("SHOP_DB")
    ?? "Host=localhost;Port=5432;Database=shop;Username=app;Password=change_me_app";

// One NpgsqlDataSource per application: it owns the connection pool.
var builder = new NpgsqlDataSourceBuilder(connectionString);
builder.ConfigureJsonOptions(new JsonSerializerOptions(JsonSerializerDefaults.Web));
builder.EnableDynamicJson();                          // jsonb <-> POCO
await using var dataSource = builder.Build();

ConnectionStringOptions();
await Setup();
await Scalar();
await ParametersAndReader();
await Transaction();
await ArraysAndJsonb();
await CallFunctionAndProcedure();
await BulkCopy();
await ListenNotify();

void ConnectionStringOptions()
{
    var csb = new NpgsqlConnectionStringBuilder(connectionString)
    {
        MaxPoolSize = 50,               // default 100
        MinPoolSize = 0,
        ConnectionIdleLifetime = 300,   // seconds before idle connections are closed
        Timeout = 15,                   // seconds to wait for a connection
        CommandTimeout = 30,            // seconds per command
        ApplicationName = "shop-sample" // visible in pg_stat_activity
    };
    Console.WriteLine($"== connection string\n{csb}\n");
}

async Task Setup()
{
    var sql = await File.ReadAllTextAsync(Path.Combine(AppContext.BaseDirectory, "setup.sql"));
    await using var cmd = dataSource.CreateCommand(sql);
    await cmd.ExecuteNonQueryAsync();
}

async Task Scalar()
{
    await using var cmd = dataSource.CreateCommand("SELECT count(*) FROM orders");
    var count = (long)(await cmd.ExecuteScalarAsync())!;
    Console.WriteLine($"== scalar\norders: {count}\n");
}

async Task ParametersAndReader()
{
    // $1, $2 = positional parameters: values never become part of the SQL text.
    await using var cmd = dataSource.CreateCommand(
        "SELECT id, name, price FROM products WHERE category = $1 AND price < $2 ORDER BY price DESC LIMIT 5");
    cmd.Parameters.Add(new NpgsqlParameter { Value = "electronics" });
    cmd.Parameters.Add(new NpgsqlParameter { Value = 100m });

    Console.WriteLine("== parameters + reader");
    await using var reader = await cmd.ExecuteReaderAsync();
    while (await reader.ReadAsync())
        Console.WriteLine($"{reader.GetInt64(0),5}  {reader.GetString(1),-14} {reader.GetDecimal(2),8}");
    Console.WriteLine();
}

async Task Transaction()
{
    await using var conn = await dataSource.OpenConnectionAsync();
    await using var tx = await conn.BeginTransactionAsync();

    await using var decrement = new NpgsqlCommand(
        "UPDATE products SET stock = stock - 1 WHERE id = $1 AND stock > 0", conn, tx);
    decrement.Parameters.Add(new NpgsqlParameter { Value = 1L });
    if (await decrement.ExecuteNonQueryAsync() == 0)
        throw new InvalidOperationException("out of stock");

    await using var insert = new NpgsqlCommand(
        "INSERT INTO orders (user_id, product_id, qty) VALUES ($1, $2, 1) RETURNING id", conn, tx);
    insert.Parameters.Add(new NpgsqlParameter { Value = 42L });
    insert.Parameters.Add(new NpgsqlParameter { Value = 1L });
    var orderId = (long)(await insert.ExecuteScalarAsync())!;

    Console.WriteLine($"== transaction\ncreated order {orderId} — rolling back to keep the dataset unchanged\n");
    await tx.RollbackAsync();                          // real code: await tx.CommitAsync();
}

async Task ArraysAndJsonb()
{
    // .NET array -> Postgres array: WHERE id = ANY($1)
    await using var byIds = dataSource.CreateCommand("SELECT id, attrs FROM products WHERE id = ANY($1) ORDER BY id");
    byIds.Parameters.Add(new NpgsqlParameter { Value = new long[] { 1, 2, 3 } });

    Console.WriteLine("== arrays + jsonb");
    await using (var reader = await byIds.ExecuteReaderAsync())
        while (await reader.ReadAsync())
        {
            var attrs = reader.GetFieldValue<ProductAttrs>(1);          // jsonb -> record
            Console.WriteLine($"product {reader.GetInt64(0)}: {attrs}");
        }

    // record -> jsonb parameter, used with the @> containment operator (GIN-indexable)
    await using var red = dataSource.CreateCommand("SELECT count(*) FROM products WHERE attrs @> $1");
    red.Parameters.Add(new NpgsqlParameter { Value = new { color = "red" }, NpgsqlDbType = NpgsqlDbType.Jsonb });
    Console.WriteLine($"red products: {await red.ExecuteScalarAsync()}\n");
}

async Task CallFunctionAndProcedure()
{
    Console.WriteLine("== function + procedure");
    await using var fn = dataSource.CreateCommand("SELECT product_id, name, units FROM top_products($1, $2)");
    fn.Parameters.Add(new NpgsqlParameter { Value = "books" });
    fn.Parameters.Add(new NpgsqlParameter { Value = 3 });
    await using (var reader = await fn.ExecuteReaderAsync())
        while (await reader.ReadAsync())
            Console.WriteLine($"{reader.GetInt64(0),5}  {reader.GetString(1),-14} units={reader.GetInt64(2)}");

    // Procedures are invoked with CALL; INOUT parameters come back as a result row.
    await using var proc = dataSource.CreateCommand("CALL product_stock($1, NULL)");
    proc.Parameters.Add(new NpgsqlParameter { Value = 1L });
    Console.WriteLine($"stock of product 1: {await proc.ExecuteScalarAsync()}\n");
}

async Task BulkCopy()
{
    // Binary COPY: the fastest way to load many rows.
    await using var conn = await dataSource.OpenConnectionAsync();
    await using (var create = new NpgsqlCommand(
        "CREATE TEMP TABLE import_events (user_id bigint, type text, created_at timestamptz)", conn))
        await create.ExecuteNonQueryAsync();

    const int rows = 100_000;
    var sw = Stopwatch.StartNew();
    await using (var writer = await conn.BeginBinaryImportAsync(
        "COPY import_events (user_id, type, created_at) FROM STDIN (FORMAT BINARY)"))
    {
        for (var i = 0; i < rows; i++)
        {
            await writer.StartRowAsync();
            await writer.WriteAsync((long)(i % 1000), NpgsqlDbType.Bigint);
            await writer.WriteAsync("click", NpgsqlDbType.Text);
            await writer.WriteAsync(DateTime.UtcNow, NpgsqlDbType.TimestampTz);
        }
        await writer.CompleteAsync();
    }
    Console.WriteLine($"== binary COPY\n{rows:N0} rows in {sw.ElapsedMilliseconds} ms\n");
}

async Task ListenNotify()
{
    // A dedicated connection receives notifications pushed by the server.
    await using var listener = await dataSource.OpenConnectionAsync();
    listener.Notification += (_, e) => Console.WriteLine($"== LISTEN/NOTIFY\nreceived '{e.Payload}' on channel '{e.Channel}'");
    await using (var listen = new NpgsqlCommand("LISTEN order_created", listener))
        await listen.ExecuteNonQueryAsync();

    await using (var notify = dataSource.CreateCommand("SELECT pg_notify('order_created', 'order 123')"))
        await notify.ExecuteNonQueryAsync();

    using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(5));
    await listener.WaitAsync(cts.Token);                                   // blocks until a notification arrives
}

record ProductAttrs(string Color, int Rating, [property: JsonPropertyName("on_sale")] bool? OnSale = null);
