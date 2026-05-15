---
name: test-infrastructure
description: "ALWAYS invoke when setting up test configs, creating data factories, or writing integration tests. Do NOT configure Vitest or create test data without checking patterns first."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Test Infrastructure

Patterns for Vitest configuration, data factories, integration tests, and test cleanup.

## Data Factory Pattern

```typescript
// tests/factories/user.factory.ts
import { ObjectId } from 'mongodb';

let counter = 0;

function nextId(): string {
  return new ObjectId().toHexString();
}

function nextEmail(): string {
  counter++;
  return `user-${counter}-${Date.now()}@test.com`;
}

export function createUser(overrides: Partial<IUser> = {}): IUser {
  return {
    _id: nextId(),
    email: nextEmail(),
    name: `Test User ${counter}`,
    password: 'HashedPassword123!',
    role: 'user',
    isActive: true,
    createdAt: new Date(),
    updatedAt: new Date(),
    ...overrides,
  };
}

export function createUsers(count: number, overrides: Partial<IUser> = {}): IUser[] {
  return Array.from({ length: count }, () => createUser(overrides));
}
```

### Random Data Helpers (no faker dependency)

```typescript
// tests/helpers/random.ts
export const random = {
  string: (length = 10) =>
    Math.random().toString(36).substring(2, 2 + length),
  number: (min: number, max: number) =>
    Math.floor(Math.random() * (max - min + 1)) + min,
  boolean: () => Math.random() > 0.5,
  date: (daysBack = 30) => {
    const d = new Date();
    d.setDate(d.getDate() - Math.floor(Math.random() * daysBack));
    return d;
  },
  pick: <T>(arr: T[]): T => arr[Math.floor(Math.random() * arr.length)]!,
  email: () => `test-${Date.now()}-${Math.random().toString(36).slice(2, 6)}@test.com`,
};
```

## Vitest Configuration

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config';
import path from 'path';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    include: ['tests/**/*.test.ts', 'tests/**/*.spec.ts'],
    exclude: ['tests/e2e/**'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov'],
      include: ['src/**/*.ts', 'server/**/*.ts'],
      exclude: ['**/*.d.ts', '**/*.test.ts'],
      thresholds: { statements: 80, branches: 75, functions: 80, lines: 80 },
    },
    setupFiles: ['tests/setup.ts'],
    testTimeout: 10000,
  },
  resolve: {
    alias: {
      '$types': path.resolve(__dirname, './types'),
      '@common': path.resolve(__dirname, './common/index.ts'),
      '@db': path.resolve(__dirname, './common/db'),
      '@': path.resolve(__dirname, './src'),
    },
  },
});
```

### Setup File

```typescript
// tests/setup.ts
import { beforeAll, afterAll, afterEach } from 'vitest';
import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose from 'mongoose';

let mongod: MongoMemoryServer;

beforeAll(async () => {
  mongod = await MongoMemoryServer.create();
  await mongoose.connect(mongod.getUri());
});

afterEach(async () => {
  const collections = mongoose.connection.collections;
  for (const key in collections) {
    await collections[key]!.deleteMany({});
  }
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongod.stop();
});
```

## Integration Test Patterns

```typescript
// tests/integration/user.service.test.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { UserService } from '@/services/user.service';
import { UserModel } from '@/models/user.model';
import { createUser } from '../factories/user.factory';

describe('UserService', () => {
  let service: UserService;

  beforeEach(() => {
    service = new UserService();
  });

  describe('createUser', () => {
    it('should create a user with hashed password', async () => {
      const input = { email: 'new@test.com', password: 'Pass123!', name: 'Test' };
      const user = await service.create(input);

      expect(user.email).toBe('new@test.com');
      expect(user.password).not.toBe('Pass123!'); // Hashed
    });

    it('should reject duplicate emails', async () => {
      const existing = createUser({ email: 'dup@test.com' });
      await UserModel.create(existing);

      await expect(
        service.create({ email: 'dup@test.com', password: 'Pass123!', name: 'Test' })
      ).rejects.toThrow(/duplicate/i);
    });
  });

  describe('findById', () => {
    it('should return null for non-existent user', async () => {
      const result = await service.findById('507f1f77bcf86cd799439011');
      expect(result).toBeNull();
    });
  });
});
```

### API Route Testing

```typescript
// tests/integration/api/users.test.ts
import { describe, it, expect } from 'vitest';
import { createUser } from '../../factories/user.factory';

describe('POST /api/users', () => {
  it('should validate required fields', async () => {
    const response = await app.inject({
      method: 'POST',
      url: '/api/users',
      payload: {},
    });

    expect(response.statusCode).toBe(400);
    expect(response.json().errors).toBeDefined();
  });

  it('should create user with valid data', async () => {
    const input = { email: 'new@test.com', password: 'Pass123!', name: 'Test' };
    const response = await app.inject({
      method: 'POST',
      url: '/api/users',
      payload: input,
    });

    expect(response.statusCode).toBe(201);
    expect(response.json().email).toBe('new@test.com');
    expect(response.json().password).toBeUndefined(); // Not exposed
  });
});
```

## Cleanup Strategy

```typescript
// Delete children before parents to avoid foreign key issues
async function cleanupDatabase() {
  const collections = ['orders', 'products', 'users', 'sessions'];
  for (const name of collections) {
    const collection = mongoose.connection.collection(name);
    if (collection) await collection.deleteMany({});
  }
}

// Per-test isolation with transaction rollback
async function withTransaction<T>(fn: () => Promise<T>): Promise<T> {
  const session = await mongoose.startSession();
  session.startTransaction();
  try {
    const result = await fn();
    await session.abortTransaction(); // Always rollback in tests
    return result;
  } finally {
    session.endSession();
  }
}
```

## Critical Rules

1. **ObjectId + counter** — Use real ObjectIds, counter for unique emails
2. **No faker** — Use simple random helpers (no heavy dependency)
3. **MongoMemoryServer** — In-memory DB for integration tests
4. **Path aliases** — Mirror project aliases in vitest.config.ts
5. **Children before parents** — Delete dependent collections first
6. **afterEach cleanup** — Clear all collections between tests
7. **Factory pattern** — `createUser(overrides)` for flexible test data
8. **Separate E2E** — Exclude `tests/e2e/` from Vitest (Playwright handles those)
