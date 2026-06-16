# Public-safe Mantis bootstrap for stock Windows.
# WHY: stock Windows has PowerShell and curl.exe, but it does not have bash,
# tmux, ttyd, or the Linux process model Mantis uses. This script keeps the
# public invite flow account-bound while installing/running Mantis inside WSL.

[CmdletBinding()]
param(
  [ValidateSet("bundle", "git")]
  [string]$Source = "bundle",
  [string]$BundleManifestUrl = "",
  [string]$ControlPlaneUrl = "https://erebora.org/mantis",
  [string]$Invite = "",
  [switch]$SkipRootAdmin,
  [switch]$SetupPhone,
  [switch]$Noninteractive,
  [string]$InstallUrl = "https://raw.githubusercontent.com/CalebDane7/mantis-install/main/install.sh"
)

$ErrorActionPreference = "Stop"

function Write-Step {
  param([string]$Message)
  Write-Host "==> $Message"
}

function Quote-Bash {
  param([string]$Value)
  $sq = [string][char]39
  $escaped = $Value.Replace($sq, $sq + '"' + $sq + '"' + $sq)
  return $sq + $escaped + $sq
}

function Get-WslDistroCount {
  try {
    $distros = & wsl.exe -l -q 2>$null
    if ($LASTEXITCODE -ne 0) { return 0 }
    $count = 0
    foreach ($line in $distros) {
      $name = ($line -replace "`0", "").Trim()
      if ($name.Length -gt 0 -and $name -notmatch "Windows Subsystem") {
        $count += 1
      }
    }
    return $count
  } catch {
    return 0
  }
}

function Ensure-Wsl {
  if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    throw "wsl.exe was not found. Install Windows Subsystem for Linux, restart if Windows asks, then rerun the same Mantis command."
  }

  if ((Get-WslDistroCount) -gt 0) {
    return
  }

  if ($Noninteractive) {
    throw "No WSL Linux distribution is installed. Run: wsl --install -d Ubuntu; restart if prompted; open Ubuntu once; then rerun the same Mantis command."
  }

  Write-Step "No WSL Linux distribution found. Installing Ubuntu through Windows WSL."
  Write-Host "Windows may ask for administrator approval or a restart. After Ubuntu opens once and creates its user, rerun this same Mantis command."
  & wsl.exe --install -d Ubuntu
  if ($LASTEXITCODE -ne 0) {
    throw "WSL Ubuntu install did not complete. Run: wsl --install -d Ubuntu, then rerun the same Mantis command."
  }
  Write-Host "WSL install started. If Windows asks for a restart or Ubuntu first-run setup, finish that and rerun the same Mantis command."
  exit 0
}

function Build-BashInstallCommand {
  $args = @("--source", $Source)
  if ($BundleManifestUrl) {
    $args += @("--bundle-manifest-url", $BundleManifestUrl)
  } elseif ($ControlPlaneUrl) {
    $args += @("--control-plane-url", $ControlPlaneUrl)
  }
  if ($Invite) {
    $args += @("--invite", $Invite)
  }
  if ($SkipRootAdmin) {
    $args += "--skip-root-admin"
  }
  if ($SetupPhone) {
    $args += "--setup-phone"
  }
  if ($Noninteractive) {
    $args += "--noninteractive"
  }

  $quotedArgs = ($args | ForEach-Object { Quote-Bash $_ }) -join " "
  $quotedInstallUrl = Quote-Bash $InstallUrl

  return @"
set -e
if ! command -v curl >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y curl ca-certificates
  else
    echo "curl is required inside WSL. Install curl in your WSL distro, then rerun Mantis." >&2
    exit 1
  fi
fi
curl -fsSL $quotedInstallUrl | bash -s -- $quotedArgs
"@
}

Ensure-Wsl
$bashCommand = Build-BashInstallCommand
Write-Step "Running Mantis install inside WSL"
& wsl.exe -- bash -lc $bashCommand
if ($LASTEXITCODE -ne 0) {
  throw "Mantis WSL install failed with exit code $LASTEXITCODE."
}
Write-Step "Mantis install complete. Open WSL and run: mantis"
