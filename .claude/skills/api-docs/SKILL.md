---
name: api-docs
description: "ALWAYS invoke after creating or modifying API endpoints, exported functions, or releasing features. Do NOT skip API documentation, JSDoc comments, or changelog entries."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# API Documentation

Patterns for API endpoint docs, JSDoc comments, and changelog management.

## API Documentation Template

````markdown
## POST /api/users

Create a new user.

### Request

**Headers:**
| Header | Required | Description |
|--------|----------|-------------|
| Authorization | Yes | Bearer token |
| Content-Type | Yes | application/json |

**Body:**
```json
{
  "email": "user@example.com",
  "password": "Password123!",
  "name": "John Doe"
}
```

**Validation:**
- email: Required, valid email format
- password: Required, min 8 chars, 1 uppercase, 1 number
- name: Required, 1-100 chars

### Response

**Success (201):**
```json
{
  "id": "abc123",
  "email": "user@example.com",
  "name": "John Doe",
  "createdAt": "2025-01-03T12:00:00Z"
}
```

**Error (400):**
```json
{
  "error": "Validation failed",
  "details": [{ "field": "email", "message": "Invalid email format" }]
}
```
````

### Documentation Location

```
docs/api/
├── README.md      # API overview
├── auth.md        # Auth endpoints
├── users.md       # User endpoints
└── openapi.yaml   # OpenAPI spec (optional)
```

## OpenAPI Quick Reference

```yaml
openapi: 3.0.3
info:
  title: My API
  version: 1.0.0
paths:
  /api/users:
    post:
      summary: Create user
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateUser'
      responses:
        '201':
          description: User created
components:
  schemas:
    CreateUser:
      type: object
      required: [email, password, name]
      properties:
        email:
          type: string
          format: email
        password:
          type: string
          minLength: 8
```

## JSDoc Patterns

```typescript
/**
 * Creates a new user in the database.
 *
 * @param data - The user creation data
 * @returns The created user document
 * @throws {ValidationError} If data is invalid
 * @throws {ConflictError} If email already exists
 *
 * @example
 * ```typescript
 * const user = await createUser({
 *   email: 'user@example.com',
 *   password: 'Password123!',
 *   name: 'John Doe'
 * });
 * ```
 */
async function createUser(data: CreateUserInput): Promise<User> {
  // Implementation
}

/** User creation input data. */
interface CreateUserInput {
  /** User email address (must be unique) */
  email: string;
  /** User password (min 8 chars, 1 uppercase, 1 number) */
  password: string;
  /** User display name */
  name: string;
}
```

| Tag | Usage |
|-----|-------|
| `@param` | Function parameter |
| `@returns` | Return value |
| `@throws` | Possible errors |
| `@example` | Usage example |
| `@deprecated` | Deprecated feature |
| `@see` | Related docs |

### When to Document

- Public API functions
- Complex algorithms
- Non-obvious behavior
- Exported types/interfaces

## Changelog Management

```markdown
# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)

## [Unreleased]

### Added
- New feature description

### Changed
- Changed behavior description

### Fixed
- Bug fix description

### Security
- Security improvement

## [1.0.0] - 2025-01-01

### Added
- Initial release features
```

| Category | Use When |
|----------|----------|
| Added | New features |
| Changed | Existing functionality changes |
| Deprecated | Soon-to-be-removed features |
| Removed | Removed features |
| Fixed | Bug fixes |
| Security | Security fixes |

### Versioning

- **MAJOR** (1.0.0): Breaking changes
- **MINOR** (0.1.0): New features, backwards compatible
- **PATCH** (0.0.1): Bug fixes

## Critical Rules

1. **Include examples** — Request and response for every endpoint
2. **List all errors** — Every possible error response code
3. **Document validation** — Field requirements and constraints
4. **Keep current** — Update docs when endpoints change
5. **Explain why** — Not just what, in JSDoc comments
6. **User perspective** — Write changelog for users, not devs
7. **Always [Unreleased]** — Keep this section at top of changelog
