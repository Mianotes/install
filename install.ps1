param(
    [string]$Dir = (Get-Location).Path,
    [string]$Ref = $env:MIANOTES_REF,
    [switch]$Dev
)

$ErrorActionPreference = "Stop"

$WebServiceRepo = if ($env:MIANOTES_WEB_SERVICE_REPO) {
    $env:MIANOTES_WEB_SERVICE_REPO
} else {
    "https://github.com/Mianotes/mianotes-web-service.git"
}

$DashboardRepo = if ($env:MIANOTES_DASHBOARD_REPO) {
    $env:MIANOTES_DASHBOARD_REPO
} else {
    "https://github.com/Mianotes/mianotes-dashboard.git"
}

function Require-Command {
    param(
        [string]$Name,
        [string]$Message
    )

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw $Message
    }
}

function Clone-Or-Update {
    param(
        [string]$RepoUrl,
        [string]$TargetDir,
        [string]$Label
    )

    $GitDir = Join-Path $TargetDir ".git"
    if (Test-Path $GitDir) {
        Write-Host "Updating $Label..."
        & git -C $TargetDir fetch --tags origin
        if ($Ref) {
            & git -C $TargetDir checkout $Ref
            & git -C $TargetDir pull --ff-only origin $Ref
        } else {
            & git -C $TargetDir pull --ff-only
        }
        return
    }

    if (Test-Path $TargetDir) {
        throw "$TargetDir already exists but is not a Git checkout. Move it or choose another -Dir."
    }

    Write-Host "Cloning $Label..."
    & git clone $RepoUrl $TargetDir
    if ($Ref) {
        & git -C $TargetDir checkout $Ref
    }
}

function Run-App-Installer {
    param(
        [string]$AppDir,
        [string]$AppName
    )

    $ScriptPath = Join-Path $AppDir "install.ps1"
    if (-not (Test-Path $ScriptPath)) {
        throw "$AppName does not provide install.ps1 at $ScriptPath"
    }

    Write-Host "Installing $AppName..."
    if ($Dev) {
        & powershell -ExecutionPolicy Bypass -File $ScriptPath -Dev
    } else {
        & powershell -ExecutionPolicy Bypass -File $ScriptPath
    }
}

Require-Command "git" "Git is required. Install Git, then run the installer again."
Require-Command "powershell" "PowerShell is required."

New-Item -ItemType Directory -Force -Path $Dir | Out-Null
$InstallDir = (Resolve-Path $Dir).Path
$WebServiceDir = Join-Path $InstallDir "mianotes-web-service"
$DashboardDir = Join-Path $InstallDir "mianotes-dashboard"

Write-Host "Installing Mianotes into:"
Write-Host "  $InstallDir"
Write-Host ""

Clone-Or-Update $WebServiceRepo $WebServiceDir "Mianotes web service"
Clone-Or-Update $DashboardRepo $DashboardDir "Mianotes dashboard"

Run-App-Installer $WebServiceDir "Mianotes web service"
Run-App-Installer $DashboardDir "Mianotes dashboard"

Write-Host ""
Write-Host "Mianotes installed."
Write-Host ""
Write-Host "Installed folders:"
Write-Host "  $WebServiceDir"
Write-Host "  $DashboardDir"
Write-Host ""
Write-Host "Start the web service:"
Write-Host "  cd `"$WebServiceDir`""
Write-Host "  mianotes-web-service init-db"
Write-Host "  mianotes-web-service --host 0.0.0.0 --port 8200"
Write-Host ""
Write-Host "Run the dashboard during development:"
Write-Host "  cd `"$DashboardDir`""
Write-Host "  npm run dev"
Write-Host ""
Write-Host "Then open:"
Write-Host "  http://127.0.0.1:8201"
