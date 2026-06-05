# Mianotes installer

This repository provides the public bootstrap installers and release package builders for Mianotes.

Most users should install Mianotes with a platform package:

- macOS: `mianotes.pkg`
- Ubuntu: `mianotes.deb`

The `install.sh` and `install.ps1` scripts are developer bootstrap installers.
They clone the app repositories into the current folder and run each app's own
development installer.

## macOS package

Most macOS users should download the package from the latest release:

```text
https://github.com/Mianotes/install/releases/latest/download/mianotes.pkg
```

The package installs Mianotes into default macOS locations:

```text
/Library/Application Support/Mianotes/
/Library/LaunchDaemons/com.mianotes.web-service.plist
/Library/LaunchDaemons/com.mianotes.dashboard.plist
/usr/local/bin/mianotes
```

After installation, Mianotes runs as two launchd services:

- `com.mianotes.web-service` on port `8200`
- `com.mianotes.dashboard` on port `8201`

Open the app with:

```bash
mianotes open
```

Run a local health check with:

```bash
mianotes doctor
```

Useful commands:

```bash
mianotes status
mianotes start
mianotes stop
mianotes doctor
mianotes logs
mianotes uninstall
```

`mianotes uninstall` removes the app services and installed app files, but keeps
your data, environment file, and workspace configuration under:

```text
/Library/Application Support/Mianotes/
```

The macOS package bundles the runtime Mianotes needs to run, including Python,
ripgrep, ffmpeg, and ffprobe. Apple Silicon packages also include a bundled
Tesseract OCR binary and English OCR data.

`mianotes doctor` shows which bundled tools are available on the current Mac
and whether any optional system fallback tools are being used.

The package is built automatically by GitHub Actions when a `v*` tag is pushed.
The workflow also supports manual runs from the GitHub Actions tab.
The release package is signed with a Developer ID Installer certificate,
submitted to Apple for notarization, and stapled before it is attached to the
GitHub release.

Build locally on macOS:

```bash
./macos/create_package.sh
```

The local build output is:

```text
dist/mianotes.pkg
```

## Ubuntu package

Ubuntu users can download the Debian package from the latest release:

```text
https://github.com/Mianotes/install/releases/latest/download/mianotes.deb
```

Install it with:

```bash
sudo apt install ./mianotes.deb
```

The package installs Mianotes into standard Linux locations:

```text
/opt/mianotes/
/etc/mianotes/mianotes.env
/lib/systemd/system/mianotes-web-service.service
/lib/systemd/system/mianotes-dashboard.service
/usr/bin/mianotes
/var/lib/mianotes/
```

After installation, Mianotes runs as two systemd services:

- `mianotes-web-service` on port `8200`
- `mianotes-dashboard` on port `8201`

The installer creates a Python virtual environment and installs the web service
dependencies during package installation, so the first install needs internet
access.
The Debian package also installs the required system packages for parsing,
audio transcription, and searching notes, including `ripgrep`, `ffmpeg`,
`flac`, and `tesseract-ocr`.

Open the app with:

```bash
mianotes open
```

Run a local health check with:

```bash
mianotes doctor
```

Useful commands:

```bash
mianotes status
mianotes start
mianotes stop
mianotes restart
mianotes doctor
mianotes logs
mianotes uninstall
```

`mianotes uninstall` removes the app services and installed app files, but keeps
your data under `/var/lib/mianotes/` and environment configuration under
`/etc/mianotes/`.

The package is built automatically by GitHub Actions when a `v*` tag is pushed.
The workflow also supports manual runs from the GitHub Actions tab.

Build locally on Ubuntu:

```bash
./linux/create_deb.sh
```

The local build output is:

```text
dist/mianotes.deb
```

## Docker image

Mianotes also ships as a single combined Docker image for servers, NAS devices,
and teams that prefer container deployment.

The image runs both services:

- Mianotes web service on port `8200`
- Mianotes dashboard on port `8201`

Start it with Docker Compose:

```bash
mkdir mianotes
cd mianotes
curl -fsSL https://raw.githubusercontent.com/Mianotes/install/main/docker-compose.yml -o docker-compose.yml
docker compose up -d
```

Then open:

```text
http://localhost:8201
```

The Compose file stores Mianotes data in the local `data/` folder:

```text
mianotes/
  docker-compose.yml
  data/
    system.db
    workspaces/
    markdown/
    html/
```

The Docker image includes the runtime dependencies needed for parsing, audio,
search, and OCR, including `ripgrep`, `ffmpeg`, `flac`, and `tesseract-ocr`.

The image is published to GitHub Container Registry:

```text
ghcr.io/mianotes/mianotes:latest
```

The Docker image is built automatically by GitHub Actions when a `v*` tag is
pushed. The workflow also supports manual runs from the GitHub Actions tab and
publishes an `edge` tag for manual builds.

## Release process

The macOS package, Ubuntu package, and Docker image are built by GitHub Actions
when a `v*` tag is pushed to this repository.

```bash
git tag v0.1.2
git push origin v0.1.2
```

The tag name becomes the package version. For example, `v0.1.2` creates
packages with version `0.1.2`.

By default, the package builders clone `main` from these repositories:

- `Mianotes/mianotes-web-service`
- `Mianotes/mianotes-dashboard`

Before creating a release tag, make sure both repositories have the intended
release commits on `main`. The workflows build:

- `dist/mianotes.pkg`
- `dist/mianotes.deb`
- `ghcr.io/mianotes/mianotes:<version>`
- `ghcr.io/mianotes/mianotes:latest`

On tag builds, both files are attached to the GitHub Release. Users can install
the latest release from:

```text
https://github.com/Mianotes/install/releases/latest/download/mianotes.pkg
https://github.com/Mianotes/install/releases/latest/download/mianotes.deb
```

The package and Docker workflows can also be run manually from the GitHub
Actions tab.

The macOS package workflow requires these GitHub Actions secrets:

```text
APPLE_DEVELOPER_ID_APPLICATION_P12_BASE64
APPLE_DEVELOPER_ID_APPLICATION_P12_PASSWORD
APPLE_DEVELOPER_ID_APPLICATION_IDENTITY
APPLE_DEVELOPER_ID_INSTALLER_P12_BASE64
APPLE_DEVELOPER_ID_INSTALLER_P12_PASSWORD
APPLE_DEVELOPER_ID_INSTALLER_IDENTITY
APPLE_NOTARY_KEY_ID
APPLE_NOTARY_ISSUER_ID
APPLE_NOTARY_KEY_BASE64
```

## macOS and Linux

This section is for developers who want editable checkouts of the web service
and dashboard.

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
