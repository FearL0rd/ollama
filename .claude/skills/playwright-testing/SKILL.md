---
name: playwright-testing
description: "ALWAYS invoke when creating or editing Playwright E2E tests. Do NOT write E2E tests without checking Page Object Model, fixture design, and multi-viewport patterns first."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Playwright Testing

Architecture patterns for Playwright E2E tests: Page Objects, fixtures, assertions, and multi-viewport testing.

## Playwright Config

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  forbidOnly: !!process.env['CI'],
  retries: process.env['CI'] ? 2 : 0,
  workers: process.env['CI'] ? 1 : undefined,
  reporter: [['html'], ['list']],
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'Desktop', use: { ...devices['Desktop Chrome'] } },
    { name: 'Tablet', use: { ...devices['iPad Mini'] } },
    { name: 'Mobile', use: { ...devices['iPhone 14'] } },
  ],
  webServer: {
    command: 'bun run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env['CI'],
  },
});
```

## Page Object Model

```typescript
// tests/e2e/pages/base.page.ts
import { type Page, type Locator, expect } from '@playwright/test';

export abstract class BasePage {
  constructor(protected page: Page) {}

  abstract readonly url: string;

  async goto() {
    await this.page.goto(this.url);
  }

  async waitForReady() {
    await this.page.waitForLoadState('networkidle');
  }

  // Shared helpers
  async getToast() {
    return this.page.locator('[data-sonner-toast]');
  }
}
```

```typescript
// tests/e2e/pages/login.page.ts
export class LoginPage extends BasePage {
  readonly url = '/login';

  // Locators (prefer data-testid, role, text)
  readonly emailInput = this.page.getByLabel('Email');
  readonly passwordInput = this.page.getByLabel('Password');
  readonly submitButton = this.page.getByRole('button', { name: 'Sign in' });
  readonly errorMessage = this.page.getByRole('alert');

  async login(email: string, password: string) {
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
    await this.submitButton.click();
  }
}
```

### Component Page Objects

```typescript
// tests/e2e/pages/components/data-table.component.ts
export class DataTableComponent {
  constructor(private container: Locator) {}

  get rows() { return this.container.getByRole('row'); }
  get headers() { return this.container.getByRole('columnheader'); }

  async sortBy(column: string) {
    await this.container.getByRole('columnheader', { name: column }).click();
  }

  async getRowCount() {
    return this.rows.count() - 1; // Minus header
  }
}
```

## Fixture Architecture

```typescript
// tests/e2e/fixtures/index.ts
import { test as base } from '@playwright/test';
import { LoginPage } from '../pages/login.page';
import { DashboardPage } from '../pages/dashboard.page';

// Worker fixture — shared across tests in same worker
// Test fixture — fresh per test
type TestFixtures = {
  loginPage: LoginPage;
  dashboardPage: DashboardPage;
  authenticatedPage: Page;
};

export const test = base.extend<TestFixtures>({
  loginPage: async ({ page }, use) => {
    await use(new LoginPage(page));
  },
  dashboardPage: async ({ page }, use) => {
    await use(new DashboardPage(page));
  },
  authenticatedPage: async ({ page }, use) => {
    // Setup: login
    await page.goto('/login');
    await page.getByLabel('Email').fill('test@example.com');
    await page.getByLabel('Password').fill('Password123!');
    await page.getByRole('button', { name: 'Sign in' }).click();
    await page.waitForURL('/dashboard');
    // Use the authenticated page
    await use(page);
    // Teardown: cleanup (automatic)
  },
});

export { expect } from '@playwright/test';
```

### Auto-fixtures (run before every test)

```typescript
export const test = base.extend<{ autoCleanup: void }>({
  autoCleanup: [async ({ page }, use) => {
    await use(); // Test runs here
    // Cleanup after test
    await page.evaluate(() => localStorage.clear());
  }, { auto: true }],
});
```

## Assertion Reference

```typescript
// Element assertions
await expect(locator).toBeVisible();
await expect(locator).toBeHidden();
await expect(locator).toBeEnabled();
await expect(locator).toBeDisabled();
await expect(locator).toBeChecked();
await expect(locator).toBeFocused();
await expect(locator).toHaveText('Expected text');
await expect(locator).toContainText('partial');
await expect(locator).toHaveValue('expected');
await expect(locator).toHaveAttribute('href', '/path');
await expect(locator).toHaveClass(/active/);
await expect(locator).toHaveCount(5);
await expect(locator).toHaveCSS('color', 'rgb(0, 0, 0)');

// Page assertions
await expect(page).toHaveURL('/expected-path');
await expect(page).toHaveURL(/\/users\/\d+/);
await expect(page).toHaveTitle('Page Title');

// Negation
await expect(locator).not.toBeVisible();

// Soft assertions (don't stop test)
await expect.soft(locator).toHaveText('text');

// Custom timeout
await expect(locator).toBeVisible({ timeout: 10000 });

// API response assertions
const response = await page.request.get('/api/users');
expect(response.ok()).toBeTruthy();
expect(response.status()).toBe(200);
```

## Multi-Viewport Testing

```typescript
// tests/e2e/responsive/dashboard.spec.ts
import { test, expect } from '../fixtures';

const viewports = [
  { name: 'Mobile', width: 375, height: 812 },
  { name: 'Tablet', width: 768, height: 1024 },
  { name: 'Desktop', width: 1280, height: 720 },
];

for (const viewport of viewports) {
  test.describe(`Dashboard - ${viewport.name}`, () => {
    test.use({ viewport: { width: viewport.width, height: viewport.height } });

    test('navigation is appropriate', async ({ page }) => {
      await page.goto('/dashboard');

      if (viewport.width < 768) {
        // Mobile: bottom nav or hamburger
        await expect(page.getByTestId('mobile-nav')).toBeVisible();
        await expect(page.getByTestId('sidebar')).toBeHidden();
      } else if (viewport.width < 1280) {
        // Tablet: collapsible sidebar
        await expect(page.getByTestId('sidebar')).toBeVisible();
      } else {
        // Desktop: full sidebar
        await expect(page.getByTestId('sidebar')).toBeVisible();
        await expect(page.getByTestId('search-bar')).toBeVisible();
      }
    });
  });
}
```

## Selector Best Practices

| Priority | Selector | Example |
|----------|----------|---------|
| 1 | `getByRole` | `getByRole('button', { name: 'Submit' })` |
| 2 | `getByLabel` | `getByLabel('Email')` |
| 3 | `getByText` | `getByText('Welcome')` |
| 4 | `getByTestId` | `getByTestId('user-avatar')` |
| 5 | CSS (last resort) | `locator('.card:first-child')` |

## Critical Rules

1. **Page Object Model** — Every page/component gets a POM class extending BasePage
2. **Fixtures over beforeEach** — Use `test.extend` for reusable setup/teardown
3. **3 viewports** — Test Mobile (375), Tablet (768), Desktop (1280+) separately
4. **Role-based selectors** — Prefer `getByRole`/`getByLabel` over CSS selectors
5. **No hardcoded waits** — Use `waitForURL`, `waitForLoadState`, `expect` auto-retry
6. **Trace on failure** — `trace: 'on-first-retry'` for debugging
7. **Parallel by default** — `fullyParallel: true` unless tests share state
8. **Worker fixtures** — Share expensive setup (auth, DB) across tests in same worker
