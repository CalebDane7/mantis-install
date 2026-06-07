# Mantis Installer

Public bootstrap for the private Mantis AI controller runtime.

## Install

Normal friend/beta install uses the account-generated command from:

```text
https://erebora.org/mantis/
```

That command includes a private `--invite` token. The bundle manifest is
protected, so a plain unauthenticated manifest URL is expected to return `401`.

Server-authorized bundle install shape:

```bash
curl -fsSL https://raw.githubusercontent.com/CalebDane7/mantis-install/main/install.sh | bash -s -- --source bundle --bundle-manifest-url https://erebora.org/mantis/api/mantis/bundles/latest.json --invite MANTIS-XXXX --noninteractive
```

Maintainer/private-source install only:

```bash
curl -fsSL https://raw.githubusercontent.com/CalebDane7/mantis-install/main/install.sh | bash
```

Maintainer key-file install:

```bash
curl -fsSL https://raw.githubusercontent.com/CalebDane7/mantis-install/main/install.sh | bash -s -- --deploy-key /path/to/mantis-deploy-key --noninteractive
```

The bootstrap contains no private source or deploy key. It installs prerequisites,
then either configures GitHub SSH access for the deploy-key lane or downloads a
checksummed runtime bundle for the server-authorized lane.
