# Flutter MCP (pub.dev)

Cursor agents working on **lululu_game** can use the **pubdev** MCP server to query [pub.dev](https://pub.dev) without leaving the IDE.

## What it provides

- Search Dart/Flutter packages with filters and sorting
- Package metadata, dependencies, and download stats
- Version history, update checks, and dependency diffs between versions
- README, changelog, and documentation snippets from pub.dev

Upstream: [@devqxi/pubdev-mcp-server](https://www.npmjs.com/package/@devqxi/pubdev-mcp-server) (stdio MCP over Node).

## Cursor configuration

The server is registered in `~/.cursor/mcp.json` under the key `pubdev`:

```json
"pubdev": {
  "command": "npx",
  "args": ["-y", "@devqxi/pubdev-mcp-server"]
}
```

Requires **Node.js** and network access on first run (`npx` downloads the package). Restart Cursor or reload MCP servers after editing `mcp.json`.

## Typical uses for this repo

- Compare alternatives before adding a dependency to `pubspec.yaml` (e.g. audio, persistence, physics helpers)
- Check compatible versions against `environment.sdk` in `pubspec.yaml` (`^3.11.5` at time of writing)
- Read changelogs before `flutter pub upgrade`

## Not covered here

Unity tooling uses a separate MCP entry (`unityMCP` in the same config). Flutter work should rely on **pubdev** and the Flutter/Dart toolchain, not Unity MCP.
