param()

$ErrorActionPreference = 'Stop'

function Write-Section($title) {
  Write-Host "`n=== $title ===" -ForegroundColor Cyan
}

function Wait-Url($url, $attempts = 20, $sleepSec = 2) {
  for ($i = 1; $i -le $attempts; $i++) {
    try {
      Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 -Uri $url | Out-Null
      return $true
    } catch {
      # If the server responded (e.g., 401/403/500), treat as available
      if ($_.Exception.Response) { return $true }
      Start-Sleep -Seconds $sleepSec
    }
  }
  return $false
}

Write-Section "Auth: Get JWT token"
$loginBody = @{ username = 'admin'; password = 'admin' } | ConvertTo-Json
try {
  $login = Invoke-RestMethod -Method Post -Uri 'http://localhost:8000/login' -ContentType 'application/json' -Body $loginBody
  Write-Host "Login response:" -ForegroundColor DarkGray
  $login | ConvertTo-Json -Depth 10
} catch {
  Write-Host ("ERROR calling /login: " + $_.Exception.Message) -ForegroundColor Red
}

$token = $null
if ($null -ne $login) {
  if ($login.PSObject.Properties.Name -contains 'token') { $token = $login.token }
  elseif ($login.PSObject.Properties.Name -contains 'jwt') { $token = $login.jwt }
  elseif ($login.PSObject.Properties.Name -contains 'accessToken') { $token = $login.accessToken }
  elseif ($login.PSObject.Properties.Name -contains 'access_token') { $token = $login.access_token }
  elseif ($login -is [string]) { $token = $login }
}

$headers = $null
if ($token) {
  $headers = @{ Authorization = "Bearer $token" }
  Write-Host "Token acquired" -ForegroundColor Green
} else {
  Write-Host "No token field found in /login response. Skipping authorized todos-api check." -ForegroundColor Yellow
}

Write-Section "todos-api circuit-breaker (authorized if token available)"
if (Wait-Url 'http://localhost:8082/health/circuit-breaker') {
  try {
    if ($headers) {
      $cbTodos = Invoke-RestMethod -Uri 'http://localhost:8082/health/circuit-breaker' -Headers $headers
      $cbTodos | ConvertTo-Json -Depth 5
    } else {
      (Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:8082/health/circuit-breaker').Content
    }
  } catch {
    Write-Host ("ERROR: " + $_.Exception.Message) -ForegroundColor Red
  }
} else {
  Write-Host 'TIMEOUT waiting for todos-api' -ForegroundColor Yellow
}

Write-Section "users-api cache status (with retries)"
if (Wait-Url 'http://localhost:8083/users/cache/status') {
  try {
    if ($headers) {
      (Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:8083/users/cache/status' -Headers $headers).Content
    } else {
      (Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:8083/users/cache/status').Content
    }
  } catch {
    Write-Host ("ERROR: " + $_.Exception.Message) -ForegroundColor Red
  }
} else {
  Write-Host 'TIMEOUT waiting for users-api cache status' -ForegroundColor Yellow
}

Write-Section "Cache-Aside latency measurement"
$sw = [System.Diagnostics.Stopwatch]::StartNew()
if ($headers) {
  Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:8083/users/' -Headers $headers | Out-Null
} else {
  Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:8083/users/' | Out-Null
}
$sw.Stop()
$firstMs = [math]::Round($sw.Elapsed.TotalMilliseconds, 0)
Start-Sleep -Seconds 1
$sw = [System.Diagnostics.Stopwatch]::StartNew()
if ($headers) {
  Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:8083/users/' -Headers $headers | Out-Null
} else {
  Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:8083/users/' | Out-Null
}
$sw.Stop()
$secondMs = [math]::Round($sw.Elapsed.TotalMilliseconds, 0)
"First:  $firstMs ms"
"Second: $secondMs ms"

Write-Section "auth-api circuit-breaker baseline"
try {
  (Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:8000/health/circuit-breaker').Content
} catch {
  Write-Host ("ERROR: " + $_.Exception.Message) -ForegroundColor Red
}

Write-Section "DONE"
