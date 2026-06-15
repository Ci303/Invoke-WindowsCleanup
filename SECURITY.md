# Security Policy

## Supported versions

Use current supported versions of PowerShell and a fully updated Windows environment.

## Reporting a security issue

If you discover a security issue, do not publish it in public issues or discussions.

- Contact the maintainer directly using the repository’s contact method.
- Include:
  - what you observed
  - reproduction steps
  - PowerShell and Windows version
  - the exact command output
- Avoid including sensitive data in screenshots, logs, or snippets.

## Execution and safety guidance

These scripts modify Windows environment settings and/or registry data only under `HKCU` in their intended flow.

- Run only scripts you trust from this repository.
- Use a full backup before cleaning or destructive operations.
- Review outputs before proceeding with deletions or cleanup actions.
- Keep your logs/backup files (`.log`, `.reg`) in a secure location.

## Scope

This project does not include an automated vulnerability reporting pipeline or third-party dependency scanning.

## Disclosure process

When reporting, please include clear impact and reproducible steps so fixes can be prioritised quickly.
