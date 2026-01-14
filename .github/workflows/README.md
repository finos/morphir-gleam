# GitHub Actions Workflows

This directory contains GitHub Actions workflows for the morphir-gleam project.

## Workflows

### CI Workflow (`ci.yml`)

**Triggers:**
- Push to `main` branch
- Pull requests to `main` branch

**Jobs:**

1. **CI** (runs on all PRs and pushes):
   - **Format check**: Ensures all code is properly formatted with `gleam format`
   - **Type check**: Validates types with `gleam check` (no compilation)
   - **Tests**: Runs all test suites for both packages
   - **Build**: Compiles all packages to ensure they build successfully

2. **Release Staging** (only runs on PRs from `release/**` branches):
   - **CHANGELOG Validation**: Ensures CHANGELOG.md has been updated with release notes
   - **Multi-platform Builds**: Builds executables for all target platforms using cross-compilation
     - Linux x64
     - Linux ARM64
     - macOS x64 (Intel)
     - macOS ARM64 (Apple Silicon)
     - Windows x64
   - **Executable Tests**: Verifies each built executable runs correctly
   - **Artifact Upload**: Uploads staging builds (7-day retention)

**Usage:**
- Standard CI runs automatically on every push and PR
- Release staging only runs for PRs from branches matching `release/*`
- All checks must pass before merging

**Release Branch Workflow:**
```bash
# Create a release branch
git checkout -b release/v0.1.0

# Update CHANGELOG.md with release notes under [Unreleased]
# Update version numbers in relevant files

# Push and create PR
git push -u origin release/v0.1.0
# Create PR to main - this triggers release-staging validation
```

---

### Release Workflow (`release.yml`)

**Triggers:**
- Manual trigger via workflow_dispatch (with version input)
- Push of version tags (e.g., `v0.1.0`)
- Creation of GitHub releases

**Jobs:**

1. **CI Checks**: Runs full CI suite (format, check, test, build)

2. **Build Binaries**: Creates platform-specific executables using cross-compilation
   - Linux x64
   - Linux ARM64
   - macOS x64 (Intel)
   - macOS ARM64 (Apple Silicon)
   - Windows x64

3. **Create Release**:
   - Downloads all built binaries
   - Generates SHA256 checksums
   - Creates or updates GitHub release with binaries

**Supported Platforms:**
- ✅ Linux x64
- ✅ Linux ARM64 (via bun cross-compilation)
- ✅ macOS x64 (Intel)
- ✅ macOS ARM64 (Apple Silicon)
- ✅ Windows x64
- ⏳ Windows ARM64 (commented out - not yet supported by bun)

**Manual Trigger:**

1. Go to Actions tab in GitHub
2. Select "Release" workflow
3. Click "Run workflow"
4. Enter version (e.g., `v0.1.0`)
5. Click "Run workflow"

**Tag-based Release:**

```bash
git tag v0.1.0
git push origin v0.1.0
```

The workflow will automatically create a release with binaries.

**Artifacts:**
Each release includes:
- Platform-specific binaries (e.g., `morphir-gleam-linux-x64`)
- `SHA256SUMS.txt` - checksums for verification

## Development Notes

### Cross-Compilation

This project uses bun's built-in cross-compilation support (available since bun v1.1.5) to build executables for multiple platforms. The `build-exe` mise task accepts a `--target` parameter to specify the target platform:

```bash
# Build for Linux ARM64 on any platform
mise run build-exe -- --target=bun-linux-arm64

# Build for Windows x64 on any platform
mise run build-exe -- --target=bun-windows-x64
```

**Supported bun targets:**
- `bun-linux-x64` - Linux x86_64
- `bun-linux-arm64` - Linux ARM64
- `bun-darwin-x64` - macOS Intel
- `bun-darwin-arm64` - macOS Apple Silicon
- `bun-windows-x64` - Windows x64

### Adding New Platforms

To add support for additional platforms:

1. Add a new matrix entry in both `release.yml` and `ci.yml`
2. Ensure the platform has bun cross-compilation support
3. Specify the correct runner and `bun_target`
4. Update this README

### Testing Workflows Locally

Use [act](https://github.com/nektos/act) to test workflows locally:

```bash
# Install act
brew install act  # macOS
# or
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Run CI workflow
act -j ci

# Run release workflow
act workflow_dispatch -j build-binaries
```
