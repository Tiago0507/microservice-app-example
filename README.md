#1. Branching Strategy

Below is a clear branching strategy for both team roles.

##1.1 Developers – GitHub Flow (2.5%)

The development team uses GitHub Flow for small and frequent changes with `main` always deployable.

- main is always deployable; small and frequent changes.
- short-lived branches off main: feature/<topic>, fix/<bug>, chore/<task>, hotfix/<incident>.
- open a PR to main with mandatory review; CI must be green before merge.
- merging to main triggers CD to the target environment.
- hotfix: prioritized, quick validation, merge to main and immediate deploy.

Guards: required CI checks, branch protection on main, and required approvals.

Rationale: simplicity, agility, and short recovery times.

##1.2 Operations – GitHub Flow (2.5%)

The operations team also uses GitHub Flow for operational changes and continuous delivery.

- main is always deployable; small and frequent changes.
- short-lived branches off main: fix/<topic>, chore/<task>, hotfix/<incident>.
- PR to main with review; merging triggers CD to the target environment.
- hotfix: prioritized, quick validation, merge to main and immediate deploy.

Guards: required CI checks, branch protection on main, and required approvals.

Rationale: simplicity, agility, and short recovery times aligned with availability goals.



# 2. Implemented Cloud Design Patterns

This section describes the two cloud design patterns implemented in this app and why they matter, plus quick ways to test them locally.

## 2.1 Circuit Breaker

- Purpose: prevent cascading failures and improve resilience by short‑circuiting calls to unhealthy dependencies and probing recovery safely.
- Where it’s used:
  - todos-api (Node.js) protects Redis operations: `microservices/todos-api/circuitBreaker.js`
  - auth-api (Go) protects calls to users-api: `microservices/auth-api/circuitBreaker.go`
- Default settings in this repo:
  - todos-api: timeout 3s, error threshold 50%, reset timeout 30s, rolling window 10s
  - auth-api: maxRequests 3, interval 10s, timeout 3s, failure ratio threshold 60%
- Why it’s relevant:
  - Avoids cascading failures during outages/high latency
  - Fails fast to reduce pressure on struggling dependencies
  - Enables graceful fallbacks (e.g., default user when users-api is down)
  - Improves recovery via controlled half‑open probing

Monitoring endpoints:
```
# todos-api Circuit Breaker
GET http://localhost:8082/health/circuit-breaker

# auth-api Circuit Breaker
GET http://localhost:8000/health/circuit-breaker
```

Quick tests (Windows PowerShell):
```
# Bring stack up
docker compose up -d

# Check CB status
Invoke-RestMethod -Method GET -Uri "http://localhost:8082/health/circuit-breaker" | ConvertTo-Json -Depth 5
Invoke-RestMethod -Method GET -Uri "http://localhost:8000/health/circuit-breaker" | ConvertTo-Json -Depth 5

# Induce CB in auth-api by stopping users-api and observe fallback
docker compose stop users-api
$body = @{ username = 'admin'; password = 'admin' } | ConvertTo-Json
Invoke-RestMethod -Method POST -Uri "http://localhost:8000/login" -ContentType 'application/json' -Body $body | ConvertTo-Json -Depth 5
docker compose start users-api
```

Linux/macOS (optional):
```
chmod +x scripts/*.sh
./scripts/test-circuit-breaker.sh
```

## 2.2 Cache-Aside

- Purpose: improve read performance and scalability by caching frequently accessed data while keeping writes authoritative.
- Where it’s used:
  - users-api (Spring Boot): `microservices/users-api/src/main/java/com/elgris/usersapi/service/CacheAsideService.java`
- Default settings:
  - TTL 5 minutes, Redis cache, JSON serialization
- Why it’s relevant:
  - Faster reads after the first request (cache hits)
  - Reduces load on the backing store
  - Explicit cache control and predictable consistency for read‑heavy workloads

Management endpoints:
```
GET  http://localhost:8083/users/cache/status
POST http://localhost:8083/users/cache/evict-all
POST http://localhost:8083/users/cache/evict/{username}
```

Quick tests (Windows PowerShell):
```
# Compare first vs second request latency (second should be faster if cached)
$sw = [System.Diagnostics.Stopwatch]::StartNew(); Invoke-WebRequest -Uri "http://localhost:8083/users/" | Out-Null; $sw.Stop(); "First:  $($sw.Elapsed.TotalMilliseconds) ms"
Start-Sleep -Seconds 1
$sw = [System.Diagnostics.Stopwatch]::StartNew(); Invoke-WebRequest -Uri "http://localhost:8083/users/" | Out-Null; $sw.Stop(); "Second: $($sw.Elapsed.TotalMilliseconds) ms"

# View cache status and evict all
Invoke-RestMethod -Method GET  -Uri "http://localhost:8083/users/cache/status"
Invoke-RestMethod -Method POST -Uri "http://localhost:8083/users/cache/evict-all"
```

Notes:
- If an endpoint requires JWT, obtain a token first: `POST http://localhost:8000/login` with `{ "username": "admin", "password": "admin" }`, then call users-api with the `Authorization: Bearer <token>` header.

## 2.3 Environment configuration

As defined in `docker-compose.yml`:

todos-api
```
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_CHANNEL=log_channel
```

auth-api
```
USERS_API_ADDRESS=http://users-api:8083
JWT_SECRET=PRFT
```

users-api
```
REDIS_HOST=redis
REDIS_PORT=6379
JWT_SECRET=PRFT
```

## 2.4 Observability

- Circuit Breaker: state transitions and counts (requests, failures, successes)
- Cache-Aside: cache hits/misses, evictions, response time comparisons

## 2.5 References

- Circuit Breaker: https://martinfowler.com/bliki/CircuitBreaker.html
- Cache-Aside: https://learn.microsoft.com/azure/architecture/patterns/cache-aside
- Microservices Patterns: https://microservices.io/patterns/
- Spring Cache Abstraction: https://docs.spring.io/spring-framework/docs/current/reference/html/integration.html#cache
- Go Circuit Breaker Library: https://github.com/sony/gobreaker