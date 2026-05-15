# OWASP Top 10 (2021) - Detailed Checklist

## A01:2021 - Broken Access Control

### What to Check

- [ ] All protected routes use authentication middleware
- [ ] User ID always comes from session, never from input
- [ ] Resources filtered by user/tenant before returning
- [ ] Admin routes check admin role explicitly
- [ ] CORS configured correctly (not `*` in production)
- [ ] Directory listing disabled
- [ ] Rate limiting on sensitive endpoints

### Detection Patterns

```bash
# Find routes without auth middleware
grep -r "router\." --include="*.ts" | grep -v "auth\|middleware"

# Find user ID from input
grep -rn "userId.*req\.(body\|params\|query)" --include="*.ts"
```

### Fix Examples

```typescript
// BAD
router.get('/users/:userId', async (req, res) => {
	const user = await User.findById(req.params.userId);
});

// GOOD
router.get('/users/:userId', authMiddleware, async (req, res) => {
	if (req.user._id.toString() !== req.params.userId) {
		return res.status(403).json({ error: 'Forbidden' });
	}
	const user = await User.findById(req.params.userId);
});
```

---

## A02:2021 - Cryptographic Failures

### What to Check

- [ ] Passwords hashed with bcrypt/argon2 (not MD5/SHA1)
- [ ] Tokens generated with crypto.randomBytes
- [ ] HTTPS enforced in production
- [ ] Sensitive data not in URLs
- [ ] Cookies have Secure, HttpOnly, SameSite flags
- [ ] No secrets in code or logs

### Detection Patterns

```bash
# Find weak hashing
grep -rn "md5\|sha1\|createHash" --include="*.ts"

# Find hardcoded secrets
grep -rn "password\s*=\s*[\"']" --include="*.ts"
grep -rn "secret\s*=\s*[\"']" --include="*.ts"
```

### Fix Examples

```typescript
// BAD
const hash = crypto.createHash('md5').update(password).digest('hex');

// GOOD
import bcrypt from 'bcrypt';
const hash = await bcrypt.hash(password, 12);
```

---

## A03:2021 - Injection

### What to Check

- [ ] SQL queries use parameterized statements
- [ ] MongoDB queries use Mongoose (not raw)
- [ ] User input never concatenated into queries
- [ ] Command execution avoids user input
- [ ] LDAP/XML queries sanitized

### Detection Patterns

```bash
# Find raw query concatenation
grep -rn "\$where\|eval\|exec(" --include="*.ts"

# Find string concatenation in queries
grep -rn "find.*\+" --include="*.ts"
```

### Fix Examples

```typescript
// BAD - NoSQL injection
User.find({ username: req.body.username });
// Attacker sends: { "$gt": "" }

// GOOD - Validate type
const username = z.string().parse(req.body.username);
User.find({ username });
```

---

## A04:2021 - Insecure Design

### What to Check

- [ ] Business logic validated server-side
- [ ] Multi-step processes maintain state
- [ ] Resource limits enforced
- [ ] Rate limiting on expensive operations
- [ ] Threat modeling performed

---

## A05:2021 - Security Misconfiguration

### What to Check

- [ ] Error messages don't leak stack traces
- [ ] Default credentials changed
- [ ] Unnecessary features disabled
- [ ] Security headers set (CSP, HSTS, etc.)
- [ ] Dependencies updated regularly

### Security Headers

```typescript
app.use(
	helmet({
		contentSecurityPolicy: true,
		crossOriginEmbedderPolicy: true,
		crossOriginOpenerPolicy: true,
		crossOriginResourcePolicy: true,
		dnsPrefetchControl: true,
		frameguard: true,
		hidePoweredBy: true,
		hsts: true,
		ieNoOpen: true,
		noSniff: true,
		originAgentCluster: true,
		permittedCrossDomainPolicies: true,
		referrerPolicy: true,
		xssFilter: true,
	})
);
```

---

## A06:2021 - Vulnerable Components

### What to Check

- [ ] Dependencies audited regularly
- [ ] No known CVEs in dependencies
- [ ] Outdated packages updated
- [ ] Lock file committed

### Commands

```bash
# Check for vulnerabilities
bun audit

# Update dependencies
bun update --latest
```

---

## A07:2021 - Authentication Failures

### What to Check

- [ ] Passwords have minimum requirements
- [ ] Brute force protection (rate limiting)
- [ ] Sessions invalidated on logout
- [ ] Session timeout implemented
- [ ] MFA available for sensitive ops
- [ ] Password reset tokens expire

### Detection Patterns

```bash
# Find login without rate limiting
grep -rn "login\|signin" --include="*.ts" | grep -v "rateLimit"
```

---

## A08:2021 - Software and Data Integrity

### What to Check

- [ ] CI/CD pipeline secured
- [ ] Dependencies from trusted sources
- [ ] Code signing for releases
- [ ] Integrity checks on downloads

---

## A09:2021 - Security Logging and Monitoring

### What to Check

- [ ] Authentication attempts logged
- [ ] Access control failures logged
- [ ] Input validation failures logged
- [ ] Logs don't contain sensitive data
- [ ] Alerting configured for anomalies

### What to Log

```typescript
logger.warn('Failed login attempt', {
	ip: req.ip,
	username: req.body.username,
	timestamp: new Date().toISOString(),
	// Never log password!
});
```

---

## A10:2021 - Server-Side Request Forgery (SSRF)

### What to Check

- [ ] URLs validated before fetching
- [ ] Internal networks blocked
- [ ] Allowlist for external services
- [ ] Response type validated

### Fix Examples

```typescript
// BAD - SSRF vulnerable
const response = await fetch(req.body.url);

// GOOD - Validate URL
const allowedHosts = ['api.example.com'];
const url = new URL(req.body.url);
if (!allowedHosts.includes(url.hostname)) {
	throw new Error('Host not allowed');
}
const response = await fetch(url.toString());
```
