# OpenCode Model Filters V2

Dynamic per-provider model filtering for OpenCode V2.

This plugin restores the practical V1 behavior of `whitelist` and `blacklist` without modifying or replacing the OpenCode executable.

## Why this exists

OpenCode V2 accepts the old provider filter fields in configuration but removes them during V1-to-V2 normalization. As a result, users with many providers can see hundreds or thousands of models in the picker.

The plugin applies the filters through OpenCode V2's model transform API, after the current provider catalog is discovered.

## Installation

### One-command installer

On Linux and macOS, run this command in a terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/GaboEI/opencode-model-filters-v2/main/install.sh | bash
```

The installer clones the latest version into `~/.config/opencode/plugins/opencode-model-filters-v2`, adds the plugin to the normal OpenCode configuration, and creates timestamped backups before changing existing files. It does not modify the OpenCode executable. Restart OpenCode after it completes.

To inspect the installer before running it, download it first and read `install.sh` from this repository.

### Windows PowerShell

In PowerShell, run:

```powershell
irm https://raw.githubusercontent.com/GaboEI/opencode-model-filters-v2/main/install.ps1 | iex
```

The PowerShell installer performs the same backup, installation, and configuration steps. It uses the standard OpenCode configuration location under your user profile, or the path provided by `OPENCODE_CONFIG`.

Add the repository path or an installed package to the `plugin` array in `~/.config/opencode/opencode.json`:

```json
{
  "plugin": [
    "opencode-model-filters-v2"
  ]
}
```

For a local checkout:

```json
{
  "plugin": [
    "/absolute/path/to/opencode-model-filters-v2-repo/src/index.js"
  ]
}
```

Restart OpenCode after changing the configuration.

## Configuration

Continue editing the normal OpenCode configuration file directly. The plugin reads the same provider rules from `opencode.json` (or the path in `OPENCODE_CONFIG`).

```json
{
  "provider": {
    "openrouter": {
      "whitelist": [
        "openai/gpt-5.6-luna",
        "deepseek/deepseek-v4.1-flash"
      ]
    },
    "google": {
      "blacklist": [
        "gemini-embedding-001",
        "veo-3.1-generate-preview"
      ]
    }
  }
}
```

Rules are evaluated per provider:

| Configuration | Result |
| --- | --- |
| Neither list is present | Every discovered model is shown, including new models |
| `blacklist` | Listed IDs are hidden; newly published IDs appear automatically |
| `whitelist` | Only listed IDs are shown; new IDs remain hidden until added |
| Both lists | The whitelist is applied first, then the blacklist removes matching IDs |

Model IDs must match the IDs reported by OpenCode for that provider. Changes take effect after an OpenCode reload or restart.

## Update behavior

The plugin does not patch, replace, wrap, or pin the OpenCode executable. OpenCode can be upgraded normally. The plugin runs against the provider catalog exposed by the installed version, so newly discovered models are evaluated on every reload.

If OpenCode later provides an official replacement for provider filtering, this plugin can be removed by deleting its entry from the `plugin` array.

## Safety and scope

- No credentials are read or transmitted.
- No provider API calls are made by this plugin.
- No model definitions are cached or copied into a second catalog.
- Providers without filters are left untouched.
- Filtering is additive to OpenCode's normal discovery; it does not change how models are called.

## Development

```bash
npm test
```

## Community context

The OpenCode V2 migration guide currently lists provider `whitelist` and `blacklist` as accepted-but-unsupported legacy fields. The related feature request for a native V2 replacement is [anomalyco/opencode#49986](https://github.com/anomalyco/opencode/issues/49986).

## License

MIT. See [LICENSE](LICENSE).
