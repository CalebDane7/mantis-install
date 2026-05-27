# Mantis Installer

Public bootstrap for the private Mantis AI controller runtime.

## Install

Interactive key paste:

```bash
curl -fsSL https://raw.githubusercontent.com/CalebDane7/mantis-install/main/install.sh | bash
```

Key file:

```bash
curl -fsSL https://raw.githubusercontent.com/CalebDane7/mantis-install/main/install.sh | bash -s -- --deploy-key /path/to/mantis-deploy-key --noninteractive
```

Server-authorized bundle manifest:

```bash
curl -fsSL https://raw.githubusercontent.com/CalebDane7/mantis-install/main/install.sh | bash -s -- --source bundle --bundle-manifest-url https://<mantis-host>/api/mantis/bundles/latest.json --invite MANTIS-XXXX-XXXX --noninteractive
```

The bootstrap contains no private source or deploy key. It installs prerequisites,
then either configures GitHub SSH access for the deploy-key lane or downloads a
checksummed runtime bundle for the server-authorized lane.
