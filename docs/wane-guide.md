# 👁️ WANE Watcher & CLI Guide

**WANE (Warnings And Errors)** is an intelligent 24/7 log collector and terminal inspector designed for the Flint Homelab Server. It continuously monitors the `systemd` journal for system degradation, container crashes, and hardware warnings, writing them to a centralized log file and providing an instant CLI inspector.

---

## ⚡ Why WANE?

Standard `journalctl` output is overwhelmingly noisy, mixing millions of informational debug logs with critical alerts. WANE filters everything down to the levels that actually matter:
- `0: emerg` (Emergency)
- `1: alert` (Action must be taken immediately)
- `2: crit` (Critical conditions)
- `3: err` (Error conditions)
- `4: warning` (Warning conditions)

---

## 🖥️ Command-Line Interface (`wane`)

The `wane` binary is globally available in `$PATH` across your system.

### 1. View Logs (`--show`)

Syntax:
```bash
wane --show [count] [order] [type]
```

- **`[count]`**: Number of log entries to display (e.g., `10`, `50`, `100`, or `all`). Default: `20`.
- **`[order]`**: Display order:
  - `desc` : Newest entries first (default).
  - `asc`  : Oldest entries first.
- **`[type]`**: Severity filter:
  - `all`  : Warnings and errors combined (default).
  - `error`: Errors and critical failures only (`[ERR]`, `[CRIT]`, `[ALERT]`, `[EMERG]`).
  - `warn` : Warnings only (`[WARN]`).

#### Examples:
```bash
# View the 20 most recent warnings and errors (newest first)
wane --show

# View the last 50 errors only
wane --show 50 desc error

# View the oldest 10 warnings
wane --show 10 asc warn

# View all logged errors in chronological order
wane --show all asc error
```

---

### 2. Follow Live Logs (`--follow`)

Stream warnings and errors in real-time as they are written by systemd services or Docker containers:
```bash
wane --follow
```

---

### 3. Check Collector Status (`--status`)

Inspect daemon health, log file path, disk size, total lines, and error vs warning breakdown:
```bash
wane --status
```

Example output:
```text
========================================
   WANE Watcher: Collector Status
========================================
Daemon Status:   ACTIVE (Running)
Log File Path:   /home/kryisnn/.config/flint/wane-log
Log File Size:   248 KB
Total Lines:     1,420
Warnings (WARN): 1,180
Errors (ERR):    240
========================================
```

---

### 4. Clear Log (`--clear`)

Wipes the central `wane-log` file safely and resets line counters without restarting the daemon:
```bash
wane --clear
```

---

## ⚙️ Declarative NixOS Configuration

WANE is enabled declaratively in [`hosts/homelab/default.nix`](../hosts/homelab/default.nix):

```nix
homelab.shellRepo.waneWatcher = {
  enable = true;
  logFile = "/home/kryisnn/.config/flint/wane-log"; # Log destination
  maxLogSizeMB = 50;                               # Auto-rotation threshold
  user = "root";                                   # Collector process user
};
```

### Self-Healing Service Architecture
WANE runs under systemd as `wane-watcher.service`:
- **Auto-restart:** Configured with `Restart = "always"` and `RestartSec = "10s"`.
- **Journal Dependency:** Starts automatically after `systemd-journald.service`.
- **Git Ignore Protection:** When `logFile` resides inside your flake repository, it is added to `.gitignore` to prevent infinite Git commit loops with `auto-vc`.

---

## 🔍 Service Management Commands

```bash
# Inspect systemd unit status
systemctl status wane-watcher.service

# Restart collector daemon
sudo systemctl restart wane-watcher.service

# View daemon internal logs
journalctl -u wane-watcher.service -f
```
