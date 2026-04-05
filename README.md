# Claw Code Linux 🦀

Static Linux builds of [Claw Code](https://github.com/ultraworkers/claw-code) with automatic update monitoring and [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) integration.

## Quick Install

```bash
curl -sSL https://raw.githubusercontent.com/raiden076/claw-code-linux/main/install-claw.sh | bash
```

## Features

- ✅ **Static binaries** - No Rust toolchain needed
- ✅ **Automatic updates** - Daily monitoring of upstream repos
- ✅ **CLIProxyAPI integration** - Use your existing AI subscriptions
- ✅ **One-command update** - `install-claw.sh update`
- ✅ **WhatsApp notifications** - Get notified when updates are available

## What Gets Installed

1. **Claw** - Static binary from GitHub releases (~5MB)
2. **Bun** - Fast JavaScript runtime (optional, if no runtime found)
3. **CLIProxyAPI** - Pre-built binary from official releases (~12MB)

## Usage

### Interactive Mode
```bash
claw                    # Start REPL
claw prompt "hi"        # One-shot mode
claw --help             # Show help
```

### With Proxy (use existing subscriptions)
```bash
claw-with-proxy         # Uses CLIProxyAPI for API routing
```

### Update to Latest
```bash
# Method 1: Re-run installer with update flag
curl -sSL https://raw.githubusercontent.com/raiden076/claw-code-linux/main/install-claw.sh | bash -s -- update

# Method 2: If already installed locally
install-claw.sh update
```

## Proxy Configuration

Edit `~/.claw-proxy/config.yaml` to add your AI provider accounts:

```yaml
providers:
  gemini:
    - name: "personal"
      auth_type: "oauth"
  
  claude:
    - name: "personal"
      auth_type: "oauth"
```

Then authenticate:
```bash
~/.claw-proxy/cliproxyapi login
```

Start the proxy:
```bash
~/.claw-proxy/start-proxy.sh
```

Or install as systemd service:
```bash
sudo cp ~/.claw-proxy/claw-proxy.service /etc/systemd/system/
sudo systemctl enable --now claw-proxy
```

## Update Monitoring

This repository includes automatic update monitoring:

- **Checks daily at 9am** for upstream changes
- **Monitors:**
  - `ultraworkers/claw-code` (new commits)
  - `router-for-me/CLIProxyAPI` (new releases)
- **Actions on update:**
  - Syncs changes to this fork
  - Triggers new GitHub Actions build
  - Sends WhatsApp notification

### Manual Check
```bash
cd ~/claw-code-linux
./scripts/update-checker.sh
```

## File Structure

```
~/claw-code-linux/
├── install-claw.sh           # Main installer
├── scripts/
│   ├── update-checker.sh     # Daily update monitor
│   ├── trigger-rebuild.sh    # Sync & rebuild trigger
│   └── run-daily-check.sh    # Cron wrapper
├── .update-state/            # State files (commit SHAs, etc.)
└── .github/workflows/
    └── build-linux.yml       # GitHub Actions build
```

## Supported Platforms

- **x86_64** (`x86_64-unknown-linux-musl`)
- **ARM64** (`aarch64-unknown-linux-musl`)

Fully static binaries - work on any Linux distribution.

## Documentation

- Claw Code: [Original Repo](https://github.com/ultraworkers/claw-code)
- CLIProxyAPI: [Help Docs](https://help.router-for.me/)

## License

Same as upstream Claw Code project.