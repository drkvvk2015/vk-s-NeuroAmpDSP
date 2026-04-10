param(
    [switch]$ReleaseBuild
)

$ErrorActionPreference = 'Stop'

Set-Location "$PSScriptRoot/.."

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    Write-Host $Label -ForegroundColor Cyan
    Invoke-Expression $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Step failed with exit code ${LASTEXITCODE}: $Command"
    }
}

Invoke-Step "[1/5] flutter pub get" "flutter pub get"

Invoke-Step "[2/5] flutter analyze" "flutter analyze"

Invoke-Step "[3/5] flutter test" "flutter test"

Invoke-Step "[4/5] flutter build apk --debug" "flutter build apk --debug"

if ($ReleaseBuild) {
    Invoke-Step "[5/5] flutter build apk --release (prod flavor)" "flutter build apk --release --dart-define=APP_FLAVOR=prod"
} else {
    Write-Host "[5/5] Skipping release build (pass -ReleaseBuild to include)" -ForegroundColor Yellow
}

Write-Host "Release QA script completed successfully." -ForegroundColor Green
