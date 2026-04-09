# ProjectPulse

A macOS menu bar app and widget suite that visualizes your Git commit activity across all local repositories.

![Swift](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-14.0+-000000?logo=apple&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Charts-007AFF?logo=swift&logoColor=white)
![WidgetKit](https://img.shields.io/badge/WidgetKit-Enabled-34C759?logo=apple&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Apple%20Silicon-8E8E93?logo=apple&logoColor=white)

## Features

- **Dashboard** — Contribution heatmap, per-repo line charts, and sortable repo list with sparkline graphs
- **Menu Bar** — Quick-glance popover showing top repos by 7-day commit activity
- **Widgets** — Three WidgetKit sizes (small, medium, large) with commit line graphs
- **Auto-scan** — Recursively discovers Git repos under a configurable root path
- **Multi-author** — Filter commits by one or more author emails
- **Persisted settings** — Sort preferences, chart opacity, scan depth, display count, and menu bar visibility

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI, Swift Charts |
| Widgets | WidgetKit |
| Menu Bar | AppKit (NSStatusItem + NSPopover) |
| Data | Git CLI (`git log`), JSON file persistence |
| Concurrency | Swift Concurrency (actors, async/await) |
| Build | Xcode 16, Swift 6 strict concurrency |

## Getting Started

```bash
# Clone and build
git clone https://github.com/avonbereghy/project-pulse.git
cd project-pulse

# Build, install to ~/Applications, and launch
./build.sh
```

The build script compiles a Release build, copies the app to `~/Applications/`, registers the widget extension, and launches the app.

## Configuration

Open **Settings** in the app sidebar to configure:

| Setting | Default | Description |
|---------|---------|-------------|
| Scan Root | `~/Projects` | Root directory to search for Git repos |
| Max Depth | 5 | How deep to recurse when finding repos |
| Day Range | 90 | Number of days of commit history to display |
| Display Count | 10 | Max repos shown in the dashboard list |
| Author Emails | — | Filter commits to specific authors |
| Chart Opacity | 100% | Opacity of line chart strokes |
| Show in Menu Bar | On | Toggle the menu bar icon |

## Architecture

```
project-pulse/
├── App/
│   ├── ProjectPulseApp.swift    # App entry, MenuBarManager (AppKit)
│   ├── ContentView.swift        # Navigation, dashboard, charts
│   ├── MenuBarView.swift        # Menu bar popover content
│   ├── RepoListViewModel.swift  # Observable state, sorting, scanning
│   ├── GitScanner.swift         # Actor — repo discovery + git log parsing
│   ├── SparklineView.swift      # Per-repo bar chart (lazy rendered)
│   ├── ContributionGraphView.swift  # GitHub-style heatmap grid
│   └── SettingsView.swift       # App preferences form
├── Shared/
│   ├── DataStore.swift          # JSON persistence + AppSettings
│   └── RepoInfo.swift           # Core models (RepoInfo, CommitDay)
├── Widget/
│   └── ProjectPulseWidget.swift # WidgetKit extension (3 sizes)
└── build.sh                     # Build + deploy script
```

## MCP Server

A built-in MCP server exposes ProjectPulse data as 15 read-only tools for Claude Code and other MCP clients. Query your coding activity conversationally — ask about commit streaks, domain focus, repo comparisons, and more.

**Requires the ProjectPulse app to be running.** The server checks the app process on every tool call.

### Setup

```bash
cd mcp-server
./build.sh
```

Add to your Claude Code config (`~/.claude/settings.json`):

```json
{
  "mcpServers": {
    "project-pulse": {
      "command": "node",
      "args": ["/path/to/project-pulse/mcp-server/dist/index.js"]
    }
  }
}
```

### Tools

| Tool | Description |
|------|-------------|
| `list_repos` | List all tracked repositories with commit stats and domain tags |
| `get_repo` | Get detailed info about a specific repository |
| `search_repos` | Search repositories by name or path |
| `activity_summary` | Overview of coding activity across all repositories |
| `commit_history` | Daily commit counts for a repo or all repos |
| `streak_analysis` | Commit streak and consistency patterns |
| `weekly_report` | This week vs last week comparison |
| `domain_breakdown` | Activity broken down by domain (NLP, App Dev, etc.) |
| `repo_tags` | View domain tags for a specific repository |
| `domain_repos` | List all repositories in a specific domain |
| `compare_repos` | Side-by-side comparison of 2-5 repositories |
| `trend_analysis` | Weekly commit trends and direction |
| `get_settings` | Current ProjectPulse configuration |
| `server_status` | App status, data freshness, server health |
| `scan_repo` | Live git scan bypassing the cache |

## License

MIT
