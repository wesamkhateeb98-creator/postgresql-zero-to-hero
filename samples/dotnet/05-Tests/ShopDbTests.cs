// Integration tests against a real, throwaway PostgreSQL (Testcontainers) — needs Docker.
// Run:  dotnet test 05-Tests
using Npgsql;
using Respawn;
using Testcontainers.PostgreSql;

public sealed class ShopDbFixture : IAsyncLifetime
{
    private readonly PostgreSqlContainer _container = new PostgreSqlBuilder("postgres:17").Build();

    private Respawner _respawner = null!;

    public NpgsqlDataSource DataSource { get; private set; } = null!;

    public async Task InitializeAsync()
    {
        await _container.StartAsync();                               // ~2–5 s: pulls/starts postgres:17
        DataSource = NpgsqlDataSource.Create(_container.GetConnectionString());

        var schema = await File.ReadAllTextAsync(Path.Combine(AppContext.BaseDirectory, "schema.sql"));
        await using (var cmd = DataSource.CreateCommand(schema))
            await cmd.ExecuteNonQueryAsync();

        await using var conn = await DataSource.OpenConnectionAsync();
        _respawner = await Respawner.CreateAsync(conn, new RespawnerOptions
        {
            DbAdapter = DbAdapter.Postgres,
            SchemasToInclude = ["public"],
            WithReseed = true
        });
    }

    /// <summary>Empty every table between tests (much faster than recreating the container).</summary>
    public async Task ResetAsync()
    {
        await using var conn = await DataSource.OpenConnectionAsync();
        await _respawner.ResetAsync(conn);
    }

    public async Task DisposeAsync()
    {
        await DataSource.DisposeAsync();
        await _container.DisposeAsync();
    }
}

public sealed class ShopDbTests(ShopDbFixture db) : IClassFixture<ShopDbFixture>, IAsyncLifetime
{
    public Task InitializeAsync() => db.ResetAsync();
    public Task DisposeAsync() => Task.CompletedTask;

    [Fact]
    public async Task Negative_qty_is_rejected_by_check_constraint()
    {
        var (userId, productId) = await SeedAsync(stock: 10);

        var ex = await Assert.ThrowsAsync<PostgresException>(() =>
            ExecAsync("INSERT INTO orders (user_id, product_id, qty) VALUES ($1, $2, -1)", userId, productId));

        Assert.Equal(PostgresErrorCodes.CheckViolation, ex.SqlState);        // 23514
    }

    [Fact]
    public async Task Duplicate_email_is_rejected_by_unique_constraint()
    {
        await SeedAsync(stock: 1);

        var ex = await Assert.ThrowsAsync<PostgresException>(() =>
            ExecAsync("INSERT INTO users (email, name, country) VALUES ('a@test.io', 'dup', 'JO')"));

        Assert.Equal(PostgresErrorCodes.UniqueViolation, ex.SqlState);       // 23505
    }

    [Fact]
    public async Task Atomic_decrement_never_oversells_under_concurrency()
    {
        var (_, productId) = await SeedAsync(stock: 10);

        // 50 concurrent buyers, 10 items in stock
        var results = await Task.WhenAll(Enumerable.Range(0, 50).Select(_ =>
            ExecAsync("UPDATE products SET stock = stock - 1 WHERE id = $1 AND stock > 0", productId)));

        await using var cmd = db.DataSource.CreateCommand("SELECT stock FROM products WHERE id = $1");
        cmd.Parameters.Add(new NpgsqlParameter { Value = productId });

        Assert.Equal(10, results.Sum());                                     // exactly 10 sales succeeded
        Assert.Equal(0, (int)(await cmd.ExecuteScalarAsync())!);             // never negative
    }

    private async Task<(long UserId, long ProductId)> SeedAsync(int stock)
    {
        await using var cmd = db.DataSource.CreateCommand(
            """
            WITH u AS (INSERT INTO users (email, name, country) VALUES ('a@test.io', 'A', 'JO') RETURNING id),
                 p AS (INSERT INTO products (name, category, price, stock) VALUES ('Keyboard', 'electronics', 49.90, $1) RETURNING id)
            SELECT u.id, p.id FROM u, p
            """);
        cmd.Parameters.Add(new NpgsqlParameter { Value = stock });
        await using var reader = await cmd.ExecuteReaderAsync();
        await reader.ReadAsync();
        return (reader.GetInt64(0), reader.GetInt64(1));
    }

    private async Task<int> ExecAsync(string sql, params object[] args)
    {
        await using var cmd = db.DataSource.CreateCommand(sql);
        foreach (var arg in args) cmd.Parameters.Add(new NpgsqlParameter { Value = arg });
        return await cmd.ExecuteNonQueryAsync();
    }
}
