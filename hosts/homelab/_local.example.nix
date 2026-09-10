# Copy this file to _local.nix and replace the values for your machine.
# _local.nix is intentionally ignored by Git so personal deployment data does
# not become part of the reusable repository.
{
  hostName = "homelab";
  primaryUser = "operator";
  primaryUid = 1000;
  timeZone = "UTC";

  git = {
    name = null;
    email = null;
  };

  sshAuthorizedKeys = [];
  tailscaleSshUsers = [];

  backupRepository = "/var/backup/restic";
  weatherLocation = null;
  cameraDevice = "/dev/video0";
  photoAlbumName = "Automated Captures";
  photoAlbumDescription = "Automated camera captures";
  photoDeviceId = "server-camera";

  # Use a path: flake reference so ignored _local.nix is included by nh.
  flakePath = "path:/etc/nixos";
  repoPath = "/etc/nixos";
  autoVcEnable = false;
}
