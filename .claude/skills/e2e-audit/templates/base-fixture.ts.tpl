// {{SESSION_DIR}}/fixtures/base.ts — e2e-audit base fixture
// Renders a Playwright test with three fixtures:
//   1. apiErrors: asserts no unexpected 4xx/5xx on API paths during the test
//   2. consoleErrors: fails when any console.error fires (with ignore list)
//   3. authenticatedPage: uses storageState from $STORAGE_STATE
//
// Use: import { test, expect } from './fixtures/base';
import { test as base, expect, type Page } from '@playwright/test';

const IGNORED_API_PATTERNS: (string | RegExp)[] = [
  /\/api\/auth\//,       // next-auth heartbeats
  /\/_next\//,
  /\/__nextjs_/,
  /hot-update/,
  /\.well-known\//,
];

const IGNORED_CONSOLE_PATTERNS: (string | RegExp)[] = [
  /React DevTools/,
  /Download the React DevTools/,
  /\[Fast Refresh\]/,
];

type ApiError = { url: string; method: string; status: number; body: string };

export const test = base.extend<{
  apiErrors: ApiError[];
  consoleErrors: string[];
  authenticatedPage: Page;
}>({
  apiErrors: async ({ page }, use) => {
    const errors: ApiError[] = [];
    page.on('response', async (res) => {
      const url = res.url();
      const isApi = /\/api\/|\/v1\/|\/trpc\//.test(url);
      if (!isApi) return;
      if (IGNORED_API_PATTERNS.some((p) => (typeof p === 'string' ? url.includes(p) : p.test(url)))) return;
      if (res.status() < 400) return;
      let body = '';
      try { body = (await res.text()).slice(0, 400); } catch {}
      errors.push({ url, method: res.request().method(), status: res.status(), body });
    });
    await use(errors);
    if (errors.length > 0) {
      const lines = errors.map((e) => `  ${e.method} ${e.url} → ${e.status}  ${e.body.replace(/\s+/g, ' ')}`);
      throw new Error(`API errors during test:\n${lines.join('\n')}`);
    }
  },

  consoleErrors: async ({ page }, use) => {
    const errors: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() !== 'error') return;
      const text = msg.text();
      if (IGNORED_CONSOLE_PATTERNS.some((p) => (typeof p === 'string' ? text.includes(p) : p.test(text)))) return;
      errors.push(text);
    });
    page.on('pageerror', (err) => errors.push(`pageerror: ${err.message}`));
    await use(errors);
    if (errors.length > 0) {
      throw new Error(`Console errors during test:\n${errors.map((e) => `  ${e}`).join('\n')}`);
    }
  },

  authenticatedPage: async ({ browser }, use) => {
    const context = await browser.newContext({
      storageState: process.env.E2E_STORAGE_STATE || '.e2e-audit/current/auth/owner.json',
    });
    const page = await context.newPage();
    await use(page);
    await context.close();
  },
});

export { expect };
