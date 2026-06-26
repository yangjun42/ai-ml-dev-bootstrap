# Parses all PowerShell scripts in this repo without executing them.
# This catches syntax errors such as accidental "$var:" interpolation.
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Failed = $false

Get-ChildItem -Path $RepoRoot -Recurse -Filter '*.ps1' | Sort-Object FullName | ForEach-Object {
    $Tokens = $null
    $Errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$Tokens, [ref]$Errors) | Out-Null
    if ($Errors -and $Errors.Count -gt 0) {
        $Failed = $true
        Write-Host "Syntax errors in $($_.FullName):" -ForegroundColor Red
        foreach ($Err in $Errors) {
            Write-Host ("  line {0}, col {1}: {2}" -f $Err.Extent.StartLineNumber, $Err.Extent.StartColumnNumber, $Err.Message) -ForegroundColor Red
        }
    } else {
        Write-Host "OK: $($_.FullName)"
    }
}

if ($Failed) { exit 1 }
Write-Host 'All PowerShell scripts parsed successfully.'
