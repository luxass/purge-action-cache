# purge-action-cache

GitHub Action for purging GitHub Actions Cache entries.

## Usage

### Example workflow

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
      - name: Purge GitHub Actions Cache
        uses: luxass/purge-action-cache@v0.0.0
        with:
          max-age: 604800 # 7 days in seconds
          filter-key: last_accessed_at # or created_at
          debug: true # optional, set to true for debug output
```

## License

Licensed under the MIT License. See [LICENSE](LICENSE) for details.
