# Invoke-WindowsCleanup.ps1

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell)
![Last Commit](https://img.shields.io/github/last-commit/Ci303/Invoke-WindowsCleanup?label=last%20commit)
![License](https://img.shields.io/github/license/Ci303/Invoke-WindowsCleanup)

## Purpose

`Invoke-WindowsCleanup.ps1` runs an interactive Windows cleanup routine with guardrails, including elevation handling, service-state preservation, and transcript logging.

## What it does

- Checks if script is running as Administrator and offers relaunch with elevation
- Starts a transcript in `%TEMP%`
- Backs up and restores service state when stopping/restarting specific services
- Performs guarded directory cleanup operations
- Optionally skips built-in Disk Cleanup (`Cleanmgr`) with `-SkipCleanMgr`

## Requirements

- Windows PowerShell 5.1+
- Policy-execution context that permits script execution
- Local admin rights for full functionality

## Usage

```powershell
cd "C:\Users\noswi\Desktop\Scripts\Invoke-WindowsCleanup"
.\Invoke-WindowsCleanup.ps1
```

Optional parameter:

```powershell
.\Invoke-WindowsCleanup.ps1 -SkipCleanMgr
```

## Parameters

- `-SkipCleanMgr`
  - When set, skips launching `cleanmgr.exe`

## Output and log

A transcript is written to:

```text
%TEMP%\\WindowsCleanup_YYYYMMDD_HHMMSS.log
```

Review this log for all steps and warnings.

## Troubleshooting

- **Script asks for admin relaunch:** expected for full cleanup actions.
- **Access denied on files/folders:** some targets may be protected or in use; warnings are logged.
- **Explorer/service behaviour:** if service changes are blocked, the script attempts to continue with warnings.

## Maintenance note

This script is interactive by design. Run manually in a test session before routine deployment.

