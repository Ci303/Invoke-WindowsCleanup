# Interactive Windows cleanup script
# Save as: Invoke-WindowsCleanup.ps1
# Run from PowerShell. If not elevated, the script will prompt to relaunch as Administrator.

[CmdletBinding()]
param(
    [switch]$SkipCleanMgr
)

$ErrorActionPreference = "Continue"

function Test-IsAdministrator {
    $principal = New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )

    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Convert-BoundParametersToArgumentList {
    param([hashtable]$BoundParameters)

    $arguments = @()

    foreach ($key in $BoundParameters.Keys) {
        $value = $BoundParameters[$key]

        if ($value -is [System.Management.Automation.SwitchParameter]) {
            if ($value.IsPresent) {
                $arguments += "-$key"
            }
        }
        elseif ($value -is [bool]) {
            if ($value) {
                $arguments += "-$key"
            }
        }
        elseif ($null -ne $value) {
            $escapedValue = $value.ToString().Replace('"', '\"')
            $arguments += "-$key"
            $arguments += "`"$escapedValue`""
        }
    }

    return $arguments
}

function Invoke-SelfElevation {
    param([hashtable]$ScriptBoundParameters)

    if (Test-IsAdministrator) {
        return
    }

    Write-Host "`nThis script is not running as Administrator." -ForegroundColor Yellow

    if ([string]::IsNullOrWhiteSpace($PSCommandPath)) {
        Write-Host "The script must be saved as a .ps1 file before it can relaunch as Administrator." -ForegroundColor Red
        Write-Host "Do not run it as a selected block in Visual Studio Code." -ForegroundColor Red
        exit 1
    }

    $answer = Read-Host "Relaunch as Administrator now? [Y/n]"

    if ($answer.Trim().ToLowerInvariant() -in @("n", "no")) {
        Write-Host "No cleanup was performed." -ForegroundColor Yellow
        exit 0
    }

    $powershellExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $scriptArgs = Convert-BoundParametersToArgumentList -BoundParameters $ScriptBoundParameters

    $argumentList = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-NoExit",
        "-File", "`"$PSCommandPath`""
    ) + $scriptArgs

    try {
        Start-Process -FilePath $powershellExe -ArgumentList $argumentList -Verb RunAs
        exit 0
    }
    catch {
        Write-Host "Failed to relaunch as Administrator: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

Invoke-SelfElevation -ScriptBoundParameters $PSBoundParameters

$LogPath = Join-Path $env:TEMP ("WindowsCleanup_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))
Start-Transcript -Path $LogPath -Force | Out-Null

function Write-Step {
    param([string]$Message)
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Format-Bytes {
    param($Bytes)

    if ($null -eq $Bytes) {
        return "Unknown"
    }

    if ($Bytes -ge 1TB) {
        return "{0:N2} TB" -f ($Bytes / 1TB)
    }

    if ($Bytes -ge 1GB) {
        return "{0:N2} GB" -f ($Bytes / 1GB)
    }

    if ($Bytes -ge 1MB) {
        return "{0:N2} MB" -f ($Bytes / 1MB)
    }

    if ($Bytes -ge 1KB) {
        return "{0:N2} KB" -f ($Bytes / 1KB)
    }

    return "$Bytes bytes"
}

function Get-DriveFreeSpaceBytes {
    param([string]$DriveLetter)

    $drive = Get-PSDrive -Name $DriveLetter.TrimEnd(":") -ErrorAction SilentlyContinue

    if ($drive) {
        return [long]$drive.Free
    }

    return $null
}

function Get-DirectorySizeBytes {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return 0
    }

    try {
        $files = Get-ChildItem -LiteralPath $Path -Force -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)
        }

        $sum = ($files | Measure-Object -Property Length -Sum).Sum

        if ($null -eq $sum) {
            return 0
        }

        return [long]$sum
    }
    catch {
        Write-Warning "Could not fully measure: $Path"
        return 0
    }
}

function Stop-ServicePreserveState {
    param([string[]]$Names)

    $states = @{}

    foreach ($name in $Names) {
        $svc = Get-Service -Name $name -ErrorAction SilentlyContinue

        if ($null -eq $svc) {
            Write-Warning "Service not found: $name"
            continue
        }

        $states[$name] = $svc.Status

        if ($svc.Status -eq "Running") {
            Write-Host "Stopping service: $name"
            Stop-Service -Name $name -Force -ErrorAction SilentlyContinue

            try {
                $svc.WaitForStatus("Stopped", "00:00:20")
            }
            catch {
                Write-Warning "Timed out while stopping service: $name"
            }
        }
    }

    return $states
}

function Restore-ServiceState {
    param([hashtable]$States)

    foreach ($name in $States.Keys) {
        if ($States[$name] -eq "Running") {
            $svc = Get-Service -Name $name -ErrorAction SilentlyContinue

            if ($svc -and $svc.Status -ne "Running") {
                Write-Host "Restarting service: $name"
                Start-Service -Name $name -ErrorAction SilentlyContinue
            }
        }
    }
}

function Remove-DirectoryContentsSafe {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$Description = $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host "Not found: $Path"
        return
    }

    Write-Host "Cleaning: $Description"
    Write-Host "Path: $Path"

    try {
        Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue |
        Where-Object {
            -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)
        } |
        ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-Warning "Failed while cleaning $Path`: $($_.Exception.Message)"
    }
}

function Remove-DirectoryTreeSafe {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$Description = $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host "Not found: $Path"
        return
    }

    Write-Host "Removing: $Description"
    Write-Host "Path: $Path"

    try {
        takeown.exe /F $Path /R /D Y | Out-Null
        icacls.exe $Path /grant Administrators:F /T /C | Out-Null
        Remove-Item -LiteralPath $Path -Force -Recurse -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "Failed to remove $Path`: $($_.Exception.Message)"
    }
}

function Confirm-Choice {
    param(
        [string]$Prompt,
        [bool]$DefaultNo = $true
    )

    if ($DefaultNo) {
        $suffix = "[y/N]"
    }
    else {
        $suffix = "[Y/n]"
    }

    $answer = Read-Host "$Prompt $suffix"

    if ([string]::IsNullOrWhiteSpace($answer)) {
        return -not $DefaultNo
    }

    return $answer.Trim().ToLowerInvariant() -in @("y", "yes")
}

try {
    Write-Step "Checking administrator rights"
    Write-Host "Running as Administrator."

    $systemDriveLetter = $env:SystemDrive.TrimEnd(":")
    $beforeFree = Get-DriveFreeSpaceBytes -DriveLetter $systemDriveLetter

    Write-Step "Scanning cleanup candidates"

    $windowsUpdateCache = Join-Path $env:SystemRoot "SoftwareDistribution\Download"
    $deliveryOptimisationCache = Join-Path $env:SystemRoot "ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache"
    $windowsTemp = Join-Path $env:SystemRoot "Temp"
    $userTemp = $env:TEMP

    $werArchive = Join-Path $env:ProgramData "Microsoft\Windows\WER\ReportArchive"
    $werQueue = Join-Path $env:ProgramData "Microsoft\Windows\WER\ReportQueue"
    $werTemp = Join-Path $env:ProgramData "Microsoft\Windows\WER\Temp"

    $windowsBt = Join-Path ($env:SystemDrive + "\") '$Windows.~BT'
    $windowsWs = Join-Path ($env:SystemDrive + "\") '$Windows.~WS'

    $standardCandidates = @(
        [pscustomobject]@{
            Name           = "Windows Update download cache"
            Path           = $windowsUpdateCache
            EstimatedBytes = 0
            Risk           = "Low. Windows can re-download required update files."
        },
        [pscustomobject]@{
            Name           = "Delivery Optimisation cache"
            Path           = $deliveryOptimisationCache
            EstimatedBytes = 0
            Risk           = "Low. Windows may re-download shared update content later."
        },
        [pscustomobject]@{
            Name           = "Windows temp folder"
            Path           = $windowsTemp
            EstimatedBytes = 0
            Risk           = "Low to medium. Files currently in use will normally fail to delete."
        },
        [pscustomobject]@{
            Name           = "User temp folder"
            Path           = $userTemp
            EstimatedBytes = 0
            Risk           = "Low to medium. Some installers or apps may still expect recent temp files."
        },
        [pscustomobject]@{
            Name           = "Windows Error Reporting archive"
            Path           = $werArchive
            EstimatedBytes = 0
            Risk           = "Low. Removes old crash reports used for troubleshooting."
        },
        [pscustomobject]@{
            Name           = "Windows Error Reporting queue"
            Path           = $werQueue
            EstimatedBytes = 0
            Risk           = "Low. Removes queued crash reports."
        },
        [pscustomobject]@{
            Name           = "Windows Error Reporting temp"
            Path           = $werTemp
            EstimatedBytes = 0
            Risk           = "Low. Removes temporary crash-reporting files."
        }
    )

    $optionalCandidates = @(
        [pscustomobject]@{
            Name           = "Recycle Bin"
            Path           = "Recycle Bin"
            EstimatedBytes = $null
            Risk           = "Medium. This permanently removes deleted files that may still be recoverable from the Recycle Bin."
        },
        [pscustomobject]@{
            Name           = 'Windows upgrade leftovers: $Windows.~BT'
            Path           = $windowsBt
            EstimatedBytes = 0
            Risk           = "Medium to high. This may remove files used to roll back after a Windows feature upgrade."
        },
        [pscustomobject]@{
            Name           = 'Windows upgrade leftovers: $Windows.~WS'
            Path           = $windowsWs
            EstimatedBytes = 0
            Risk           = "Medium to high. This may remove files used by Windows setup or upgrade rollback."
        }
    )

    foreach ($candidate in $standardCandidates) {
        $candidate.EstimatedBytes = Get-DirectorySizeBytes -Path $candidate.Path
    }

    foreach ($candidate in $optionalCandidates) {
        if ($candidate.Path -ne "Recycle Bin") {
            $candidate.EstimatedBytes = Get-DirectorySizeBytes -Path $candidate.Path
        }
    }

    $standardTotal = ($standardCandidates | Measure-Object -Property EstimatedBytes -Sum).Sum
    $optionalKnownTotal = (
        $optionalCandidates |
        Where-Object { $null -ne $_.EstimatedBytes } |
        Measure-Object -Property EstimatedBytes -Sum
    ).Sum

    if ($null -eq $standardTotal) {
        $standardTotal = 0
    }

    if ($null -eq $optionalKnownTotal) {
        $optionalKnownTotal = 0
    }

    Write-Step "Dry-run summary"

    Write-Host "`nStandard cleanup candidates:"
    $standardCandidates |
    Select-Object Name, Path, @{Name = "EstimatedSize"; Expression = { Format-Bytes $_.EstimatedBytes } }, Risk |
    Format-Table -AutoSize -Wrap

    Write-Host "`nOptional cleanup candidates:"
    $optionalCandidates |
    Select-Object Name, Path, @{Name = "EstimatedSize"; Expression = { Format-Bytes $_.EstimatedBytes } }, Risk |
    Format-Table -AutoSize -Wrap

    Write-Host "`nEstimated standard cleanup space: $(Format-Bytes $standardTotal)" -ForegroundColor Green
    Write-Host "Estimated optional cleanup space, excluding unknown Recycle Bin size: $(Format-Bytes $optionalKnownTotal)" -ForegroundColor Yellow

    Write-Host "`nWindows-managed cleanup also available:"
    Write-Host "- Deployment Image Servicing and Management component store cleanup: size cannot be reliably estimated here."
    Write-Host "- Disk Cleanup cleanmgr /verylowdisk: size cannot be reliably estimated here."

    Write-Step "Analysing Windows component store"
    DISM.exe /Online /Cleanup-Image /AnalyzeComponentStore

    Write-Step "Warnings before cleanup"

    Write-Host @"
This script deletes cached and temporary files.

Possible consequences:
- Windows Update may need to re-download update files.
- Delivery Optimisation may need to rebuild its cache.
- Some temporary installer files may be removed.
- Old crash reports used for troubleshooting may be removed.
- Recycle Bin clearing is permanent.
- Removing Windows upgrade leftovers may reduce or remove rollback options after a feature update.

The estimated space is not guaranteed. Some files may be locked, recreated immediately, compressed, deduplicated, or managed internally by Windows.
"@ -ForegroundColor Yellow

    $runStandard = Confirm-Choice -Prompt "Run the standard cleanup now?" -DefaultNo $true

    if (-not $runStandard) {
        Write-Host "`nNo cleanup was performed." -ForegroundColor Yellow
        Write-Host "Log saved to: $LogPath"
        exit 0
    }

    $runRecycleBin = Confirm-Choice -Prompt "Also clear the Recycle Bin?" -DefaultNo $true
    $runUpgradeLeftovers = Confirm-Choice -Prompt "Also remove Windows upgrade leftovers?" -DefaultNo $true

    Write-Step "Starting cleanup"

    Write-Step "Cleaning superseded Windows component store files"
    DISM.exe /Online /Cleanup-Image /StartComponentCleanup

    if (-not $SkipCleanMgr) {
        Write-Step "Running Disk Cleanup system tasks silently"
        cleanmgr.exe /verylowdisk
    }
    else {
        Write-Step "Skipping Disk Cleanup"
    }

    Write-Step "Clearing Windows Update download cache"

    $serviceStates = Stop-ServicePreserveState -Names @("wuauserv", "bits")

    try {
        Remove-DirectoryContentsSafe -Path $windowsUpdateCache -Description "Windows Update download cache"
    }
    finally {
        Restore-ServiceState -States $serviceStates
    }

    Write-Step "Clearing Delivery Optimisation cache"

    if (Get-Command Delete-DeliveryOptimizationCache -ErrorAction SilentlyContinue) {
        Delete-DeliveryOptimizationCache -Force -ErrorAction SilentlyContinue
    }
    else {
        Remove-DirectoryContentsSafe -Path $deliveryOptimisationCache -Description "Delivery Optimisation cache"
    }

    Write-Step "Clearing Windows temp folders"

    $tempPaths = @(
        $windowsTemp,
        $userTemp
    ) | Select-Object -Unique

    foreach ($path in $tempPaths) {
        Remove-DirectoryContentsSafe -Path $path -Description "Temporary files"
    }

    Write-Step "Clearing crash dump and error reporting files"

    $werPaths = @(
        $werArchive,
        $werQueue,
        $werTemp
    )

    foreach ($path in $werPaths) {
        Remove-DirectoryContentsSafe -Path $path -Description "Windows Error Reporting files"
    }

    if ($runRecycleBin) {
        Write-Step "Clearing Recycle Bin"
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    }
    else {
        Write-Step "Skipping Recycle Bin"
    }

    if ($runUpgradeLeftovers) {
        Write-Step "Removing Windows upgrade leftovers"

        $upgradePaths = @(
            $windowsBt,
            $windowsWs
        )

        foreach ($path in $upgradePaths) {
            Remove-DirectoryTreeSafe -Path $path -Description "Windows upgrade leftovers"
        }
    }
    else {
        Write-Step "Skipping Windows upgrade leftovers"
    }

    Write-Step "Final component store analysis"
    DISM.exe /Online /Cleanup-Image /AnalyzeComponentStore

    $afterFree = Get-DriveFreeSpaceBytes -DriveLetter $systemDriveLetter

    if ($null -ne $beforeFree -and $null -ne $afterFree) {
        $recovered = $afterFree - $beforeFree

        Write-Host "`nFree space before cleanup: $(Format-Bytes $beforeFree)" -ForegroundColor Green
        Write-Host "Free space after cleanup:  $(Format-Bytes $afterFree)" -ForegroundColor Green
        Write-Host "Approximate space recovered: $(Format-Bytes $recovered)" -ForegroundColor Green
    }

    Write-Host "`nCleanup complete. Restart Windows before rescanning disk usage." -ForegroundColor Green
    Write-Host "Log saved to: $LogPath" -ForegroundColor Green
}
finally {
    Stop-Transcript | Out-Null
}