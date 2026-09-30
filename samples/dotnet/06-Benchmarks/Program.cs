// Same query, four ways: raw Npgsql vs Dapper vs EF Core (no tracking / tracking / compiled).
// Run (Release, against the repo's shop DB):
//   dotnet run -c Release --project 06-Benchmarks
using BenchmarkDotNet.Attributes;
using BenchmarkDotNet.Running;
using Dapper;
using Microsoft.EntityFrameworkCore;
using Npgsql;

BenchmarkRunner.Run<LastOrdersOfUser>();

[MemoryDiagnoser]
public class LastOrdersOfUser
{
    private const string Sql =
        "SELECT id, user_id, product_id, qty, status, created_at FROM orders WHERE user_id = $1 ORDER BY created_at DESC LIMIT 20";

    private static readonly Func<ShopContext, long, IAsyncEnumerable<Order>> Compiled =
        EF.CompileAsyncQuery((ShopContext db, long userId) =>
            db.Orders.AsNoTracking().Where(o => o.UserId == userId).OrderByDescending(o => o.CreatedAt).Take(20));

    // Fixed user: the rows stay in shared_buffers, so the difference measured is client-side overhead.
    private const long _userId = 42;

    private NpgsqlDataSource _dataSource = null!;
    private DbContextOptions<ShopContext> _efOptions = null!;

    [GlobalSetup]
    public void Setup()
    {
        var cs = Environment.GetEnvironmentVariable("SHOP_DB")
            ?? "Host=localhost;Port=5432;Database=shop;Username=app;Password=change_me_app";
        _dataSource = NpgsqlDataSource.Create(cs);
        _efOptions = new DbContextOptionsBuilder<ShopContext>()
            .UseNpgsql(_dataSource).UseSnakeCaseNamingConvention().Options;
        DefaultTypeMap.MatchNamesWithUnderscores = true;
    }

    [GlobalCleanup]
    public void Cleanup() => _dataSource.Dispose();

    [Benchmark(Baseline = true)]
    public async Task<int> Npgsql_Raw()
    {
        await using var cmd = _dataSource.CreateCommand(Sql);
        cmd.Parameters.Add(new NpgsqlParameter { Value = _userId });
        await using var reader = await cmd.ExecuteReaderAsync();
        var list = new List<Order>(20);
        while (await reader.ReadAsync())
            list.Add(new Order
            {
                Id = reader.GetInt64(0), UserId = reader.GetInt64(1), ProductId = reader.GetInt64(2),
                Qty = reader.GetInt32(3), Status = reader.GetString(4), CreatedAt = reader.GetDateTime(5)
            });
        return list.Count;
    }

    [Benchmark]
    public async Task<int> Dapper()
    {
        await using var conn = await _dataSource.OpenConnectionAsync();
        var rows = await conn.QueryAsync<Order>(Sql.Replace("$1", "@userId"), new { userId = _userId });
        return rows.AsList().Count;
    }

    [Benchmark]
    public async Task<int> EfCore_NoTracking()
    {
        await using var db = new ShopContext(_efOptions);
        return (await db.Orders.AsNoTracking().Where(o => o.UserId == _userId)
            .OrderByDescending(o => o.CreatedAt).Take(20).ToListAsync()).Count;
    }

    [Benchmark]
    public async Task<int> EfCore_Tracking()
    {
        await using var db = new ShopContext(_efOptions);
        return (await db.Orders.Where(o => o.UserId == _userId)
            .OrderByDescending(o => o.CreatedAt).Take(20).ToListAsync()).Count;
    }

    [Benchmark]
    public async Task<int> EfCore_Compiled()
    {
        await using var db = new ShopContext(_efOptions);
        var n = 0;
        await foreach (var _ in Compiled(db, _userId)) n++;
        return n;
    }
}

public sealed class ShopContext(DbContextOptions<ShopContext> options) : DbContext(options)
{
    public DbSet<Order> Orders => Set<Order>();
}

public sealed class Order
{
    public long Id { get; set; }
    public long UserId { get; set; }
    public long ProductId { get; set; }
    public int Qty { get; set; }
    public string Status { get; set; } = "";
    public DateTime CreatedAt { get; set; }
}
