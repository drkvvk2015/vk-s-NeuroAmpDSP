param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [int]$BuildNumber,

    [switch]$Push
)

$ErrorActionPreference = 'Stop'

Set-Location "$PSScriptRoot/../.."

$pubspecPath = "app/pubspec.yaml"
$releaseVersion = "$Version+$BuildNumber"
$tagName = "release/v$Version"

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Action
    )

    Write-Host $Label -ForegroundColor Cyan
    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw "Step failed with exit code ${LASTEXITCODE}: $Label"
    }
}

$pubspecContent = Get-Content $pubspecPath -Raw
if ($pubspecContent -notmatch '^version:\s*.+$') {
    throw "Unable to find version line in $pubspecPath"
}

$updatedPubspec = [regex]::Replace(
    $pubspecContent,
    '^version:\s*.+$',
    "version: $releaseVersion",
    [System.Text.RegularExpressions.RegexOptions]::Multiline
)

Set-Content -Path $pubspecPath -Value $updatedPubspec

Invoke-Step "git add pubspec" { git add $pubspecPath }
Invoke-Step "git commit release bump" { git commit -m "chore(release): bump version to $releaseVersion" }
Invoke-Step "git tag release" { git tag $tagName }

if ($Push) {
    Invoke-Step "git push main" { git push origin main }
    Invoke-Step "git push tag" { git push origin $tagName }
} else {
    Write-Host "Push skipped. Use -Push to publish main and $tagName." -ForegroundColor Yellow
}

Write-Host "Release bump complete: $releaseVersion ($tagName)" -ForegroundColor Green