# Mianotes installer

This repository provides the public bootstrap installer for Mianotes.

## macOS and Linux

Run this from the folder where you want Mianotes installed:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Mianotes/install/HEAD/install.sh)"
```

The installer creates:

```text
mianotes-web-service/
mianotes-dashboard/
```

It then runs each app's own installer:

- `mianotes-web-service/install.sh`
- `mianotes-dashboard/install.sh`

## Windows

For native Windows PowerShell, run this from the folder where you want Mianotes installed:

```powershell
irm https://raw.githubusercontent.com/Mianotes/install/HEAD/install.ps1 | iex
```

The Bash installer also works on Windows through Git Bash or WSL.

## Options

Install somewhere else:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Mianotes/install/HEAD/install.sh)" -- --dir ~/Mianotes
```

Use a specific branch or tag:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Mianotes/install/HEAD/install.sh)" -- --ref main
```

## Requirements

- Git
- Python 3.11 or newer
- Node.js and npm

The app installers check these requirements and explain what is missing.
