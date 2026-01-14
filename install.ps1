# Morphir Gleam Installer for Windows
# Install the morphir-gleam CLI tool on Windows
#
# Usage:
#   irm https://raw.githubusercontent.com/finos/morphir-gleam/main/install.ps1 | iex
#   $env:VERSION="v0.1.0"; irm https://raw.githubusercontent.com/finos/morphir-gleam/main/install.ps1 | iex
#
# Environment variables:
#   MORPHIR_INSTALL_DIR - Installation directory (default: $env:LOCALAPPDATA\Programs\morphir-gleam)
#   VERSION             - Specific version to install (default: latest)

param(
    [string]$Version = $env:VERSION
)

$ErrorActionPreference = "Stop"

# Configuration
$GitHubRepo = "finos/morphir-gleam"
$BinaryName = "morphir-gleam.exe"
$InstallDir = if ($env:MORPHIR_INSTALL_DIR) { $env:MORPHIR_INSTALL_DIR } else { "$env:LOCALAPPDATA\Programs\morphir-gleam" }

# Colors for output
function Write-ColorOutput {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$false)]
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Detect architecture
function Get-Architecture {
    $arch = $env:PROCESSOR_ARCHITECTURE
    switch ($arch) {
        "AMD64" { return "x64" }
        "ARM64" { return "arm64" }
        default {
            Write-ColorOutput "Error: Unsupported architecture: $arch" "Red"
            exit 1
        }
    }
}

# Get the latest release version from GitHub
function Get-LatestVersion {
    param(
        [string]$SpecifiedVersion
    )

    if (-not [string]::IsNullOrEmpty($SpecifiedVersion)) {
        Write-ColorOutput "Using specified version: $SpecifiedVersion" "Blue"
        return $SpecifiedVersion
    }

    Write-ColorOutput "Fetching latest release version..." "Blue"

    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$GitHubRepo/releases/latest"
        $version = $response.tag_name

        if ([string]::IsNullOrEmpty($version)) {
            Write-ColorOutput "Error: Could not determine latest version" "Red"
            exit 1
        }

        Write-ColorOutput "Latest version: $version" "Green"
        return $version
    }
    catch {
        Write-ColorOutput "Error fetching latest version: $_" "Red"
        exit 1
    }
}

# Download and install the binary
function Install-Binary {
    param(
        [string]$Version,
        [string]$Architecture
    )

    $downloadUrl = "https://github.com/$GitHubRepo/releases/download/$Version/morphir-gleam-windows-$Architecture.exe"
    $tempFile = "$env:TEMP\$BinaryName"

    Write-ColorOutput "Downloading morphir-gleam from $downloadUrl..." "Blue"

    try {
        # Download with progress
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile
        $ProgressPreference = 'Continue'

        if (-not (Test-Path $tempFile)) {
            Write-ColorOutput "Error: Download failed" "Red"
            exit 1
        }

        # Create install directory if it doesn't exist
        if (-not (Test-Path $InstallDir)) {
            New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
        }

        # Move to install directory
        Move-Item -Path $tempFile -Destination "$InstallDir\$BinaryName" -Force

        Write-ColorOutput "✓ Installed to $InstallDir\$BinaryName" "Green"
    }
    catch {
        Write-ColorOutput "Error during installation: $_" "Red"
        exit 1
    }
}

# Verify installation
function Test-Installation {
    if (Test-Path "$InstallDir\$BinaryName") {
        Write-ColorOutput "Verifying installation..." "Blue"
        try {
            & "$InstallDir\$BinaryName" version
            Write-ColorOutput "✓ Installation successful!" "Green"
        }
        catch {
            Write-ColorOutput "Error: Installation verification failed" "Red"
            exit 1
        }
    }
    else {
        Write-ColorOutput "Error: Binary not found at $InstallDir\$BinaryName" "Red"
        exit 1
    }
}

# Check and update PATH
function Update-Path {
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")

    if ($currentPath -notlike "*$InstallDir*") {
        Write-ColorOutput "Adding $InstallDir to PATH..." "Yellow"

        try {
            [Environment]::SetEnvironmentVariable(
                "Path",
                "$currentPath;$InstallDir",
                "User"
            )

            # Update PATH for current session
            $env:Path += ";$InstallDir"

            Write-ColorOutput "✓ Added to PATH (restart your shell to use 'morphir-gleam' directly)" "Green"
        }
        catch {
            Write-ColorOutput "Warning: Could not automatically add to PATH" "Yellow"
            Write-ColorOutput "Please manually add '$InstallDir' to your PATH" "Yellow"
        }
    }
    else {
        Write-ColorOutput "✓ Install directory already in PATH" "Green"
    }
}

# Main installation flow
function Main {
    Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Green"
    Write-ColorOutput "  Morphir Gleam Installer" "Green"
    Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Green"
    Write-Host ""

    $arch = Get-Architecture
    Write-ColorOutput "Detected architecture: windows-$arch" "Blue"

    $installVersion = Get-LatestVersion -SpecifiedVersion $Version
    Install-Binary -Version $installVersion -Architecture $arch
    Test-Installation
    Update-Path

    Write-Host ""
    Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Green"
    Write-ColorOutput "  Installation complete!" "Green"
    Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Green"
    Write-Host ""
    Write-ColorOutput "Run 'morphir-gleam --help' to get started" "Blue"
    Write-ColorOutput "(You may need to restart your shell first)" "Yellow"
}

Main
