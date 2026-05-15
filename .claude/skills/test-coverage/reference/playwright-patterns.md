# Playwright E2E Testing Patterns

## Page Object Model (POM)

### Base Page

```typescript
// tests/e2e/pages/base.page.ts
import { Page, Locator } from '@playwright/test';

export abstract class BasePage {
	readonly page: Page;

	constructor(page: Page) {
		this.page = page;
	}

	async goto(path: string): Promise<void> {
		await this.page.goto(path);
	}

	async waitForLoad(): Promise<void> {
		await this.page.waitForLoadState('networkidle');
	}

	getByTestId(id: string): Locator {
		return this.page.getByTestId(id);
	}

	async takeScreenshot(name: string): Promise<void> {
		await this.page.screenshot({ path: `screenshots/${name}.png` });
	}
}
```

### Specific Page

```typescript
// tests/e2e/pages/login.page.ts
import { BasePage } from './base.page';

export class LoginPage extends BasePage {
	readonly emailInput = this.getByTestId('email-input');
	readonly passwordInput = this.getByTestId('password-input');
	readonly submitButton = this.getByTestId('submit-button');
	readonly errorMessage = this.getByTestId('error-message');

	async login(email: string, password: string): Promise<void> {
		await this.emailInput.fill(email);
		await this.passwordInput.fill(password);
		await this.submitButton.click();
	}

	async expectError(message: string): Promise<void> {
		await expect(this.errorMessage).toContainText(message);
	}
}
```

---

## Custom Fixtures

### Database Fixture

```typescript
// tests/e2e/fixtures/db.fixture.ts
import { test as base } from '@playwright/test';
import { MongoClient, Db, ObjectId } from 'mongodb';

type DbFixture = {
	db: Db;
	createdIds: Map<string, ObjectId[]>;
	trackCreated: (collection: string, id: ObjectId) => void;
};

export const test = base.extend<DbFixture>({
	db: async ({}, use) => {
		const client = await MongoClient.connect(process.env['MONGODB_URI']!);
		const db = client.db();
		await use(db);
		await client.close();
	},

	createdIds: async ({}, use) => {
		await use(new Map());
	},

	trackCreated: async ({ createdIds }, use) => {
		const track = (collection: string, id: ObjectId) => {
			const ids = createdIds.get(collection) || [];
			ids.push(id);
			createdIds.set(collection, ids);
		};
		await use(track);
	},
});

// Auto-cleanup after each test
test.afterEach(async ({ db, createdIds }) => {
	for (const [collection, ids] of createdIds.entries()) {
		if (ids.length > 0) {
			await db.collection(collection).deleteMany({
				_id: { $in: ids },
			});
		}
	}
});
```

### Auth Fixture

```typescript
// tests/e2e/fixtures/auth.fixture.ts
import { test as base } from '@playwright/test';

type AuthFixture = {
	authenticatedPage: Page;
};

export const test = base.extend<AuthFixture>({
	authenticatedPage: async ({ browser }, use) => {
		const context = await browser.newContext({
			storageState: 'tests/e2e/.auth/user.json',
		});
		const page = await context.newPage();
		await use(page);
		await context.close();
	},
});
```

---

## Multi-Viewport Testing

### Config

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
	projects: [
		{
			name: 'Desktop Chrome',
			use: { ...devices['Desktop Chrome'] },
		},
		{
			name: 'Tablet',
			use: { ...devices['iPad'] },
		},
		{
			name: 'Mobile',
			use: { ...devices['iPhone 14'] },
		},
	],
});
```

### Viewport-Aware Tests

```typescript
test('navigation adapts to viewport', async ({ page, isMobile }) => {
	await page.goto('/');

	if (isMobile) {
		// Mobile: hamburger menu
		await expect(page.getByTestId('hamburger-menu')).toBeVisible();
		await page.getByTestId('hamburger-menu').click();
		await expect(page.getByTestId('mobile-nav')).toBeVisible();
	} else {
		// Desktop: sidebar
		await expect(page.getByTestId('sidebar')).toBeVisible();
	}
});
```

---

## API Testing

### REST

```typescript
test.describe('REST API', () => {
	test('requires authentication', async ({ request }) => {
		const response = await request.get('/api/users');
		expect(response.status()).toBe(401);
	});

	test('validates input', async ({ request }) => {
		const response = await request.post('/api/users', {
			data: { email: 'invalid' },
		});
		expect(response.status()).toBe(400);
		const body = await response.json();
		expect(body.errors).toBeDefined();
	});
});
```

### tRPC

```typescript
test.describe('tRPC API', () => {
	test('handles validation errors', async ({ request }) => {
		const response = await request.post('/api/trpc/user.create', {
			data: { json: { name: '' } },
		});
		const body = await response.json();
		expect(body.error.data.code).toBe('BAD_REQUEST');
	});
});
```

---

## Best Practices

### Use data-testid

```tsx
// Component
<button data-testid="submit-button">Submit</button>;

// Test
await page.getByTestId('submit-button').click();
```

### Wait for Network

```typescript
// Wait for all network requests to finish
await page.waitForLoadState('networkidle');

// Wait for specific request
await page.waitForResponse('/api/users');
```

### Retries for Flaky Tests

```typescript
// playwright.config.ts
export default defineConfig({
	retries: process.env.CI ? 2 : 0,
});
```

### Screenshots on Failure

```typescript
// playwright.config.ts
export default defineConfig({
	use: {
		screenshot: 'only-on-failure',
		trace: 'on-first-retry',
	},
});
```
