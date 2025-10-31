# purge-action-cache

GitHub Action for purging GitHub Actions Cache entries.

## Usage

### Modes

This action supports two modes:

- **`normal`** (default): Purge caches older than a specified age, optionally targeting a specific ref
- **`all`**: Purge all caches for the repository

### Example workflows

#### Normal mode - Purge old caches

```yaml
name: Cleanup Actions Cache

on:
  schedule:
    - cron: "0 0 * * *" # run daily
  workflow_dispatch: # allow manual triggers

jobs:
  cleanup-cache:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Purge old GitHub Actions Cache entries
        uses: luxass/purge-action-cache@v0.2.1
        with:
          mode: normal # default, can be omitted
          max-age: 604800 # 7 days in seconds (default)
          filter-key: last_accessed_at # or created_at (default: last_accessed_at)
          debug: true # optional, set to true for debug output
```

#### Normal mode - Purge old caches for a specific ref

```yaml
- name: Purge old caches for feature branch
  uses: luxass/purge-action-cache@v0.2.1
  with:
    mode: normal
    ref-key: refs/heads/feature-branch
    max-age: 86400 # 1 day in seconds
    filter-key: created_at
```

#### All mode - Purge all caches

```yaml
- name: Purge all caches
  uses: luxass/purge-action-cache@v0.2.1
  with:
    mode: all
```

## Inputs

| Input        | Description                                                                                    | Required | Default               |
| ------------ | ---------------------------------------------------------------------------------------------- | -------- | --------------------- |
| `mode`       | Cache cleanup mode: `"normal"` or `"all"`                                                      | No       | `normal`              |
| `max-age`    | Delete all caches older than this value in seconds (used with `normal` mode)                   | No       | `604800` (7 days)     |
| `filter-key` | Filter caches by `"last_accessed_at"` or `"created_at"` (used with `normal` mode)              | No       | `last_accessed_at`    |
| `ref-key`    | The branch or tag ref to target (used with `normal` mode). If not specified, uses `GITHUB_REF` | No       | `""`                  |
| `debug`      | Output debug info                                                                              | No       | `false`               |
| `token`      | GitHub token for API access                                                                    | No       | `${{ github.token }}` |

## License

Licensed under the MIT License. See [LICENSE](LICENSE) for details.
