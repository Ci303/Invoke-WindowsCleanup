# Invoke-WindowsCleanup.ps1

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell)
![Last Commit](https://img.shields.io/github/last-commit/Ci303/Invoke-WindowsCleanup?label=last%20commit)
![License](https://img.shields.io/github/license/Ci303/Invoke-WindowsCleanup)
![Issues](https://img.shields.io/github/issues/Ci303/Invoke-WindowsCleanup?label=open%20issues)

## Purpose

Run an interactive Windows cleanup workflow with guardrails, including elevation handling, service-safe operations and full transcript logging.

## What it does

- Checks for administrator context and offers relaunch with elevation if needed.
- Starts a transcript in `%TEMP%`.
- Preserves/restores service state where service control is required.
- Performs guarded directory cleanup with defensive checks.
- Optionally skips Windows Disk Cleanup when `-SkipCleanMgr` is set.

## Requirements

- Windows PowerShell 5.1+.
- Execution-policy context that allows running the script.
- Local administrator rights for full cleanup paths.

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
  - Skips launching `cleanmgr.exe`.

## Output

A transcript is written to:

```text
%TEMP%\\WindowsCleanup_YYYYMMDD_HHMMSS.log
```

Review the log for all completed steps and warnings.

## Notes

Designed to be interactive. Review the results and test in a controlled environment first.

## Troubleshooting

- If not elevated, relaunch prompt is expected.
- If services or files are in use, affected operations are logged and the script continues where possible.

## Support and contribution

- Issues and feature requests: [GitHub Issues](https://github.com/Ci303/Invoke-WindowsCleanup/issues)
- Security concerns: [SECURITY.md](./SECURITY.md)
- Contribution guidelines: [CONTRIBUTING.md](./CONTRIBUTING.md)
