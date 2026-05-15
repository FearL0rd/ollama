---
name: mongoose-patterns
description: "ALWAYS invoke when creating or editing Mongoose models, queries, or database operations. Do NOT write MongoDB code without checking schema, index, and query patterns first."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Mongoose Patterns

Comprehensive patterns for Mongoose schemas, indexes, queries, aggregations, and seeders.

## Schema Template

```typescript
// types/[entity].ts — ALL interfaces in types/ folder
export interface I[Entity] {
  field1: string;
  field2: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface I[Entity]Document extends I[Entity], Document {
  comparePassword(password: string): Promise<boolean>;
}

export interface I[Entity]Model extends Model<I[Entity]Document> {
  findByEmail(email: string): Promise<I[Entity]Document | null>;
}
```

```typescript
// src/models/[entity].model.ts
import type { I[Entity]Document, I[Entity]Model } from '$types/[entity]';

const [Entity]Schema = new Schema<I[Entity]Document, I[Entity]Model>(
  {
    field1: {
      type: String,
      required: [true, 'Field1 is required'],
      trim: true,
      maxlength: [100, 'Max 100 characters'],
    },
  },
  {
    timestamps: true,
    collection: '[entities]',
    toJSON: {
      transform: (_, ret) => {
        delete ret.password;
        delete ret.__v;
        return ret;
      },
    },
  }
);
```

## Index Strategy (ESR Rule)

Order compound indexes by: **Equality → Sort → Range**

```typescript
// Query: { status: "active", createdAt: { $gt: date } }.sort({ score: -1 })
// Index: { status: 1, score: -1, createdAt: 1 }
//        [Equality] [Sort]     [Range]

UserSchema.index({ email: 1 }, { unique: true });
UserSchema.index({ role: 1, isActive: 1 });  // Compound
UserSchema.index({ createdAt: 1 }, { expireAfterSeconds: 86400 }); // TTL
UserSchema.index({ name: 'text', bio: 'text' }); // Text search
UserSchema.index({ nickname: 1 }, { sparse: true }); // Only non-null
```

| Type | Syntax | Use Case |
|------|--------|----------|
| Single | `{ field: 1 }` | Frequent queries |
| Compound | `{ a: 1, b: -1 }` | Multi-field queries |
| Unique | `{ unique: true }` | No duplicates |
| Text | `{ field: 'text' }` | Full-text search |
| TTL | `{ expireAfterSeconds: N }` | Auto-expire |
| Sparse | `{ sparse: true }` | Only index non-null |
| Partial | `{ partialFilterExpression: {} }` | Conditional index |

## Query Optimization

```typescript
// Use .lean() for read-only (2-5x faster)
const users = await User.find({}).select('name email').lean();

// Use .exists() instead of findOne for checks
const exists = await User.exists({ email });

// Selective population
await Order.find({}).populate('user', 'name email');

// Cursor for large datasets
const cursor = User.find({}).cursor();
for await (const user of cursor) { /* ... */ }

// Batch operations
await Model.insertMany(items);
await Model.bulkWrite([
  { insertOne: { document: { ... } } },
  { updateOne: { filter: { ... }, update: { ... } } },
]);

// Use $in over $or
await User.find({ status: { $in: ['active', 'pending'] } });

// Pagination with count (parallel)
const [items, total] = await Promise.all([
  Model.find(query).skip((page - 1) * limit).limit(limit).lean(),
  Model.countDocuments(query),
]);
```

## Aggregation Patterns

```typescript
// Paginated search with $facet
const [result] = await Product.aggregate([
  { $match: { $text: { $search: query } } },
  {
    $facet: {
      data: [
        { $sort: { score: { $meta: 'textScore' } } },
        { $skip: (page - 1) * limit },
        { $limit: limit },
      ],
      total: [{ $count: 'count' }],
    },
  },
  {
    $project: {
      items: '$data',
      total: { $arrayElemAt: ['$total.count', 0] },
    },
  },
]);

// Sales report grouped by day
await Order.aggregate([
  { $match: { createdAt: { $gte: start, $lte: end }, status: 'completed' } },
  {
    $group: {
      _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } },
      totalSales: { $sum: '$total' },
      orderCount: { $sum: 1 },
      avgOrderValue: { $avg: '$total' },
    },
  },
  { $sort: { _id: 1 } },
]);
```

**Performance**: $match first, use indexes, $project early, $facet for parallel ops, allowDiskUse for large datasets.

## Seeder Pattern

```typescript
// scripts/seed/index.ts
async function seed() {
  await mongoose.connect(process.env['MONGODB_URI']!);
  // Clear children before parents
  await Promise.all([
    mongoose.connection.collection('orders').deleteMany({}),
    mongoose.connection.collection('products').deleteMany({}),
    mongoose.connection.collection('users').deleteMany({}),
  ]);
  const users = await seedUsers();
  const products = await seedProducts();
  await seedOrders(users, products);
  await mongoose.disconnect();
}
```

## Critical Rules

1. **Types in `types/`** — Interfaces separate from schema (I[Entity], I[Entity]Document, I[Entity]Model)
2. **`select: false`** for passwords — Hide sensitive fields by default
3. **`toJSON.transform`** — Remove password, __v from API responses
4. **`Bun.password.hash`** — Use Bun's native hashing (not bcrypt)
5. **ESR ordering** — Equality, Sort, Range for compound indexes
6. **`.lean()`** — Always for read-only queries
7. **`$facet`** — For paginated search (data + count in one query)
8. **Explain first** — Always analyze with `.explain('executionStats')` before optimizing
9. **COLLSCAN = bad** — Every frequent query needs an IXSCAN
10. **Clear children first** — Delete dependent collections before parents in seeders
