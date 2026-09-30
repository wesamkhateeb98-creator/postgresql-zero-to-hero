using Microsoft.EntityFrameworkCore;

public sealed class ShopContext(DbContextOptions<ShopContext> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<Product> Products => Set<Product>();
    public DbSet<Order> Orders => Set<Order>();

    protected override void OnModelCreating(ModelBuilder model)
    {
        // Tables and columns already exist (datasets/shop.sql); snake_case naming maps them:
        // Products -> products, CreatedAt -> created_at, ProductId -> product_id.
        model.Entity<User>().Property(u => u.Country).HasColumnType("char(2)");

        model.Entity<Product>(p =>
        {
            p.Property(x => x.Price).HasPrecision(10, 2);
            p.Property(x => x.Version).IsRowVersion();          // maps to the system column xmin
            p.OwnsOne(x => x.Attrs, a =>
            {
                a.ToJson();                                       // stored in the jsonb column "attrs"
                a.Property(x => x.Color).HasJsonPropertyName("color");
                a.Property(x => x.Rating).HasJsonPropertyName("rating");
            });
        });

        model.Entity<Order>(o =>
        {
            // Restrict = match the real FKs in shop.sql (EF's default for required FKs is CASCADE)
            o.HasOne(x => x.User).WithMany(u => u.Orders).HasForeignKey(x => x.UserId)
             .OnDelete(DeleteBehavior.Restrict);
            o.HasOne(x => x.Product).WithMany().HasForeignKey(x => x.ProductId)
             .OnDelete(DeleteBehavior.Restrict);
        });
    }
}

public sealed class User
{
    public long Id { get; set; }
    public string Email { get; set; } = "";
    public string Name { get; set; } = "";
    public string Country { get; set; } = "";
    public DateTime CreatedAt { get; set; }
    public List<Order> Orders { get; set; } = [];
}

public sealed class Product
{
    public long Id { get; set; }
    public string Name { get; set; } = "";
    public string Category { get; set; } = "";
    public decimal Price { get; set; }
    public int Stock { get; set; }
    public ProductAttrs Attrs { get; set; } = new();
    public uint Version { get; set; }                         // xmin: optimistic concurrency
}

public sealed class ProductAttrs
{
    public string? Color { get; set; }
    public int? Rating { get; set; }
}

public sealed class Order
{
    public long Id { get; set; }
    public long UserId { get; set; }
    public long ProductId { get; set; }
    public int Qty { get; set; }
    public string Status { get; set; } = "paid";
    public DateTime CreatedAt { get; set; }
    public User? User { get; set; }
    public Product? Product { get; set; }
}

public sealed record TopProduct(long ProductId, string Name, long Units);
