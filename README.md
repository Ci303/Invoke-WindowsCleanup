# Invoke-WindowsCleanup.ps1

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell)
![Last Commit](https://img.shields.io/github/last-commit/Ci303/Invoke-WindowsCleanup?label=last%20commit)
![License](https://img.shields.io/github/license/Ci303/Invoke-WindowsCleanup)
![Issues](https://img.shields.io/github/issues/Ci303/Invoke-WindowsCleanup?label=open%20issues)

## Purpose

Run an interactive Windows cleanup workflow with guardrails, including elevation handling, service-state safety and full transcript logging.

## What it does

- Checks for administrator context and offers relaunch when required.
- Starts a transcript in `%TEMP%`.
- Preserves/restores service state where service control is used.
- Performs guarded directory cleanup with defensive checks.
- Optionally skips Windows Disk Cleanup using `-SkipCleanMgr`.

## Requirements

- Windows PowerShell 5.1+.
- Execution-policy context that allows running the script.
- Local administrator rights for full cleanup paths.

## Usage

```powershell
cd "C:\Users\noswi\Desktop\Scripts\Invoke-WindowsCleanup"
.\Invoke-WindowsCleanup.ps1
```

## Output

- Transcript file in `%TEMP%` with a timestamped name.
- In-console progress and warning messages for each cleanup stage.

## Troubleshooting

- If not elevated, relaunch prompt is expected.
- If files or services are locked, affected operations are logged and skipped when necessary.

## Safety

Interactive execution only. Review logs and run in a controlled environment before broader use.

## Support and contribution

- Issues and feature requests: [GitHub Issues](https://github.com/Ci303/Invoke-WindowsCleanup/issues)
- Security concerns: [SECURITY.md](./SECURITY.md)
- Contribution guidelines: [CONTRIBUTING.md](./CONTRIBUTING.md)

## Parameters

- `-SkipCleanMgr`
  - Skips launching `cleanmgr.exe`.