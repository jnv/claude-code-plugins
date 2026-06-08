# My Claude Code plugins

> [!CAUTION]
> This repo is for personal purpose and its contents may change, break, delete your data or eat your breakfast without prior warning. Use at your own risk – or not at all.

## Install

```
/plugin marketplace add jnv/claude-code-plugins
/plugin install context-king@jnv-plugins
```

## Plugins

### context-king

Wraps [ContextKing](https://github.com/Fredrik-C/ContextKing) (`ck`) — semantic
code navigation for large codebases. The plugin ships only the skills, hooks,
and a launcher; the platform binary, native libraries, and embedding model are
downloaded on first use from a **pinned** upstream release into the plugin's
persistent data directory (so the ~60 MB download happens once). macOS + Linux
only in v1. First `ck` call requires network; later calls are offline.

## Maintenance

`scripts/ck-update.sh [--version vX.Y.Z] [--commit]` regenerates the
`context-king` payload from an upstream release (skills, hooks, checksums,
version pin). It is maintainer tooling and is not part of the installed plugin.
A scheduled GitHub Action runs it and opens a PR when upstream publishes a newer
release.
