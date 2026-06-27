# Mantis Installer

Public bootstrap for the private Mantis AI controller runtime.

## Install

Normal friend/beta install uses the account-generated command from:

```text
https://erebora.org/mantis/
```

## How To Use Mantis

- Codex is the default main director. It is fast, concise, and best for source
  recovery, dispatch, integration, and proof.
- Mantis was primarily designed for Claude and still helps Claude most with
  visual, frontend, and interface work. Ask Codex to bring in Claude for that
  work, or run `mantis claude` / choose `2` when Claude should own the lane.
- Ask Codex to bring in Antigravity/Gemini for outward-facing copy.
- Bare `mantis` can start each model directly: `1` Codex, `2` Claude,
  `3` Antigravity/Gemini.
- Auto is normal guided mode. Full `/x` is strict mode.
- Whenever Mantis starts, it emails your stable Mantis Remote terminal link.
  Open the newest Mantis email on your phone and tap `Open Mantis Remote`.
- Android APK setup is automated after the physical phone steps. Run
  `mantis phone apk-guide`, then enable Developer Options, enable USB
  debugging, connect USB, and approve the debugging prompt on the phone. Mantis
  opens Tailscale or its Play Store page on the authorized phone, then installs
  the newest APK. Future `mantis update --auto` checks for APK updates when
  that phone is reachable.
- Phone buttons: Active opens live terminals; Old reopens past sessions; New
  creates a session; Start sends Enter and runs the current prompt; Stop
  interrupts current work; Upload sends files; Copy/Paste moves text; Bottom
  jumps to newest output.

That command includes a private `--invite` token. The bundle manifest is
protected, so a plain unauthenticated manifest URL is expected to return `401`.

Server-authorized bundle install shape:

```bash
curl -fsSL https://raw.githubusercontent.com/CalebDane7/mantis-install/main/install.sh | bash -s -- --source bundle --bundle-manifest-url https://erebora.org/mantis/api/mantis/bundles/latest.json --invite MANTIS-XXXX --noninteractive
```

Stock macOS uses the same command. If Homebrew is missing, the installer asks
to install Homebrew from the official Homebrew installer, then continues with
the Mantis dependencies.

Stock Windows uses PowerShell plus WSL:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=Join-Path $env:TEMP 'mantis-install.ps1'; curl.exe -fsSL 'https://raw.githubusercontent.com/CalebDane7/mantis-install/main/install.ps1' -o $p; & $p -Source bundle -BundleManifestUrl 'https://erebora.org/mantis/api/mantis/bundles/latest.json' -Invite 'MANTIS-XXXX' -SkipRootAdmin"
```

The private bundle installer also prepares the Mantis-managed Codex home at
`~/.mantis/codex-home`. That managed home gets a generated `AGENTS.md`, Mantis
hooks, Codex memories, `gpt-5.5`, max reasoning, and full-access/no-approval
automation for `mantis codex`. It does not overwrite vanilla `~/.codex` or
vanilla `~/.claude`.

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
