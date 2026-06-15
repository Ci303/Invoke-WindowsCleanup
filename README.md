# Invoke-WindowsCleanup.ps1

Conservative Windows cleanup helper with interactive guardrails and elevation handling.

## Overview

This script performs interactive Windows cleanup routines and records a transcript for review. It is designed to be run as Administrator and contains internal safety measures:

- Self-check for admin context
- Automatic relaunch prompt with elevation when required
- Transcript logging to the temp directory
- Helper routines for safe directory cleanup and service state preservation
- Optional integration with `Cleanmgr.exe` via `-SkipCleanMgr`

## Requirements

- Windows PowerShell 5.1+
- Execution policy that allows local scripts (or a signed script run in an approved context)
- Administrator privileges for full cleanup operations

## Usage

```powershell
cd "C:\Users\noswi\Desktop\Scripts\Invoke-WindowsCleanup"
.\Invoke-WindowsCleanup.ps1
```

Optional flag:

```powershell
.\Invoke-WindowsCleanup.ps1 -SkipCleanMgr
```

## What happens

- If not elevated, the script prompts to relaunch as Administrator.
- A transcript file is started (in `%TEMP%`) for auditability.
- Cleanup tasks are executed through helper functions that are intended to avoid destructive failures where possible (for example, skip missing paths and preserve service state where it changes execution flow).

## Logging

A transcript is written to:

- `%TEMP%\\WindowsCleanup_YYYYMMDD_HHMMSS.log`

Check this file for a complete action log and any warnings.

## Notes

- Review the script before use in production environments.
- Output is designed for interactive use and includes clear section headers and progress status.

## Recommended practice

Run once, review the log, and if your environment requires it, test in a controlled machine before broad rollout.
