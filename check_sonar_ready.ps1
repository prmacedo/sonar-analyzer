param(
    [string]$SonarHost
)

$ErrorActionPreference = 'Stop'

if (-not $SonarHost) {
    $SonarHost = $env:SONAR_HOST
}

if (-not $SonarHost) {
    Write-Error 'SONAR_HOST not provided.'
    exit 2
}

$base = $SonarHost.TrimEnd('/')
$uri = "$base/api/system/status"

try {
    $response = Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 -Uri $uri
    if ($response.StatusCode -ne 200) {
        Write-Error "Unexpected status code $($response.StatusCode) from $uri"
        exit 1
    }

    try {
        $payload = $response.Content | ConvertFrom-Json
    } catch {
        Write-Error 'Failed to parse SonarQube status payload as JSON.'
        exit 1
    }

    if ($payload.status -eq 'UP') {
        exit 0
    }

    Write-Error "SonarQube status is $($payload.status)."
    exit 1
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
