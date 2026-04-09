#Requires -Version 5.1
<#
.SYNOPSIS
    Checks whether a list of websites are up or down.

.DESCRIPTION
    Reads URLs from sites.txt, performs an HTTP request for each,
    and reports status to the console and a log file.

.PARAMETER SitesFile
    Path to the text file containing URLs to check. Defaults to sites.txt
    in the same directory as this script.

.PARAMETER LogDir
    Directory where log files are written. Defaults to a "logs" folder
    next to this script.

.PARAMETER TimeoutSec
    Seconds to wait before marking a site as unreachable. Defaults to 10.

.EXAMPLE
    .\SiteChecker.ps1
    .\SiteChecker.ps1 -SitesFile "C:\my-sites.txt" -TimeoutSec 15
#>

param(
    [string]$SitesFile  = (Join-Path $PSScriptRoot "sites.txt"),
    [string]$LogDir     = (Join-Path $PSScriptRoot "logs"),
    [int]   $TimeoutSec = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Write-StatusLine {
    param([string]$Url, [string]$Status, [string]$Detail)

    $icon   = if ($Status -eq "UP") { "[+]" } else { "[-]" }
    $color  = if ($Status -eq "UP") { "Green" } else { "Red" }
    $line   = "{0,-4} {1,-45} {2}" -f $icon, $Url, $Detail

    Write-Host $line -ForegroundColor $color
    return $line
}

function Test-Site {
    param([string]$Url)

    try {
        $response = Invoke-WebRequest `
            -Uri            $Url `
            -Method         Head `
            -TimeoutSec     $TimeoutSec `
            -UseBasicParsing `
            -ErrorAction    Stop

        $code = $response.StatusCode
        if ($code -ge 200 -and $code -lt 400) {
            return @{ Status = "UP";   Detail = "HTTP $code" }
        } else {
            return @{ Status = "DOWN"; Detail = "HTTP $code" }
        }
    }
    catch [System.Net.WebException] {
        $msg = $_.Exception.Message
        # Some servers reject HEAD — retry with GET
        if ($msg -match "405|Method Not Allowed") {
            try {
                $response = Invoke-WebRequest `
                    -Uri            $Url `
                    -Method         Get `
                    -TimeoutSec     $TimeoutSec `
                    -UseBasicParsing `
                    -ErrorAction    Stop

                $code = $response.StatusCode
                if ($code -ge 200 -and $code -lt 400) {
                    return @{ Status = "UP";   Detail = "HTTP $code (GET)" }
                } else {
                    return @{ Status = "DOWN"; Detail = "HTTP $code" }
                }
            }
            catch {
                return @{ Status = "DOWN"; Detail = $_.Exception.Message }
            }
        }
        return @{ Status = "DOWN"; Detail = $msg }
    }
    catch {
        return @{ Status = "DOWN"; Detail = $_.Exception.Message }
    }
}

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

if (-not (Test-Path $SitesFile)) {
    Write-Error "Sites file not found: $SitesFile"
    exit 1
}

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

$timestamp  = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile    = Join-Path $LogDir "sitechecker_$timestamp.log"
$logLines   = [System.Collections.Generic.List[string]]::new()

$urls = Get-Content $SitesFile |
    Where-Object { $_ -notmatch '^\s*#' -and $_ -match '\S' } |
    ForEach-Object { $_.Trim() }

if ($urls.Count -eq 0) {
    Write-Warning "No URLs found in $SitesFile"
    exit 0
}

# ---------------------------------------------------------------------------
# Run checks
# ---------------------------------------------------------------------------

$header = "SiteChecker  |  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  |  Timeout: ${TimeoutSec}s"
Write-Host ""
Write-Host $header -ForegroundColor Cyan
Write-Host ("-" * 70) -ForegroundColor DarkGray
$logLines.Add($header)
$logLines.Add("-" * 70)

$upCount   = 0
$downCount = 0

foreach ($url in $urls) {
    $result = Test-Site -Url $url
    $line   = Write-StatusLine -Url $url -Status $result.Status -Detail $result.Detail
    $logLines.Add($line)

    if ($result.Status -eq "UP") { $upCount++ } else { $downCount++ }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

$summary = "`nResult: $upCount UP  |  $downCount DOWN  |  $($urls.Count) total"
Write-Host ("-" * 70) -ForegroundColor DarkGray
$summaryColor = if ($downCount -gt 0) { "Yellow" } else { "Cyan" }
Write-Host $summary -ForegroundColor $summaryColor
Write-Host ""

$logLines.Add("-" * 70)
$logLines.Add($summary)
$logLines.Add("")

# ---------------------------------------------------------------------------
# Write log
# ---------------------------------------------------------------------------

$logLines | Out-File -FilePath $logFile -Encoding UTF8
Write-Host "Log saved: $logFile" -ForegroundColor DarkGray
Write-Host ""

# Exit with non-zero code if any sites are down (useful for Task Scheduler alerting)
if ($downCount -gt 0) { exit 1 } else { exit 0 }
