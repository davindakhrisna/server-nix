# Taste

## Environment & remote access (homelab)
- Manages a NixOS homelab (hostname `homelab`, user `kryisnn`; LAN 192.168.0.112, Tailscale IP 100.119.213.3) over SSH from the Windows host, running services glance, immich, vaultwarden, n8n, couchdb. Confidence: 0.8
- When LAN SSH is unavailable, Tailscale SSH is the reliable path in (`& "$env:ProgramFiles\Tailscale\tailscale.exe" ssh kryisnn@homelab` or plain `ssh` to the Tailscale IP). Confidence: 0.7
- Windows `~/.ssh/id_ed25519` is passphrase-protected and the Windows ssh-agent service is disabled by default — non-interactive/BatchMode SSH will fail until the user starts ssh-agent (needs an admin PowerShell) and runs `ssh-add`. Budget one manual step from the user before key-based SSH works. Confidence: 0.8
- When automated remote access is blocked, the user prefers acting as the middleman: they run commands manually on the homelab and paste output back, instead of more attempts at fixing the automated connection. Hand them a short, copy-pasteable batch of commands with one-line explanations of what each reveals, and flag the subset most likely to pinpoint the issue. Confidence: 0.7
