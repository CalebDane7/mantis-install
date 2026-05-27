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

The bootstrap contains no private source or deploy key. It installs prerequisites,
configures GitHub SSH access, clones the private runtime repo, and runs the
private installer.
