import path from "node:path";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { parseDate, formatDate, textResult } from "../types.js";
import { readRepos, readSettings, getFileMtime } from "../data.js";
import { assertAppRunning, isAppRunning } from "../lifecycle.js";
import { scanRepoLive } from "../git.js";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function relativeTime(date: Date): string {
  const now = Date.now();
  const diffMs = now - date.getTime();
  const diffSeconds = Math.floor(diffMs / 1000);
  const diffMinutes = Math.floor(diffSeconds / 60);
  const diffHours = Math.floor(diffMinutes / 60);
  const diffDays = Math.floor(diffHours / 24);

  if (diffDays > 0) return `${diffDays} day${diffDays === 1 ? "" : "s"} ago`;
  if (diffHours > 0)
    return `${diffHours} hour${diffHours === 1 ? "" : "s"} ago`;
  if (diffMinutes > 0)
    return `${diffMinutes} minute${diffMinutes === 1 ? "" : "s"} ago`;
  return "just now";
}

function fileFreshness(filename: string): string {
  const mtime = getFileMtime(filename);
  return mtime ? relativeTime(mtime) : "not found";
}

// ---------------------------------------------------------------------------
// Tool registration
// ---------------------------------------------------------------------------

export function registerSystemTools(server: McpServer): void {
  // ---- get_settings ------------------------------------------------------
  server.tool(
    "get_settings",
    "View current ProjectPulse configuration",
    {},
    async () => {
      await assertAppRunning();

      const s = readSettings();
      const authors =
        s.authorEmails.length > 0 ? s.authorEmails.join(", ") : "None";

      const text = [
        "## ProjectPulse Settings",
        "",
        `**Scan root:** \`${s.scanRoot}\``,
        `**Day range:** ${s.dayRange} days`,
        `**Scan depth:** ${s.scanDepth}`,
        `**Display count:** ${s.displayCount}`,
        `**Author filters:** ${authors}`,
        `**Rescan interval:** ${s.rescanIntervalMinutes} minutes`,
      ].join("\n");

      return textResult(text);
    },
  );

  // ---- server_status -----------------------------------------------------
  server.tool(
    "server_status",
    "Check ProjectPulse app status, data freshness, and server health",
    {},
    async () => {
      const running = await isAppRunning();

      let repoCount = 0;
      try {
        repoCount = readRepos().length;
      } catch {
        // data file may be missing or corrupt
      }

      const text = [
        "## ProjectPulse Server Status",
        "",
        `**App status:** ${running ? "Running" : "Not running"}`,
        `**Server version:** 1.0.0`,
        `**Cached repos:** ${repoCount}`,
        "",
        "### Data freshness",
        "",
        `- repos.json: ${fileFreshness("repos.json")}`,
        `- settings.json: ${fileFreshness("settings.json")}`,
        `- domain-tags.json: ${fileFreshness("domain-tags.json")}`,
      ].join("\n");

      return textResult(text);
    },
  );

  // ---- scan_repo ---------------------------------------------------------
  server.tool(
    "scan_repo",
    "Run a live git scan on a repository, bypassing the cache",
    {
      path: z.string().describe("Absolute path to the git repository"),
    },
    async ({ path: repoPath }) => {
      await assertAppRunning();

      const settings = readSettings();
      const result = await scanRepoLive(repoPath, settings);

      const repoName = path.basename(repoPath);
      const totalCommits = result.commitDays.reduce(
        (sum, d) => sum + d.count,
        0,
      );
      const lastDate = result.lastCommitDate
        ? formatDate(result.lastCommitDate)
        : "None";

      // Last 30 days history
      const cutoff = new Date();
      cutoff.setDate(cutoff.getDate() - 30);
      cutoff.setHours(0, 0, 0, 0);

      const recentDays = result.commitDays
        .map((d) => ({ date: parseDate(d.date), count: d.count }))
        .filter(
          (d): d is { date: Date; count: number } =>
            d.date !== null && d.date >= cutoff,
        )
        .sort((a, b) => a.date.getTime() - b.date.getTime());

      const historyLines =
        recentDays.length === 0
          ? "No commits in the last 30 days."
          : recentDays
              .map(
                (d) =>
                  `- ${formatDate(d.date)}: ${d.count} commit${d.count === 1 ? "" : "s"}`,
              )
              .join("\n");

      const text = [
        `## Live scan: ${repoName}`,
        "",
        `**Total commits in scanned period:** ${totalCommits}`,
        `**Last commit:** ${lastDate}`,
        "",
        "### Last 30 days",
        "",
        historyLines,
      ].join("\n");

      return textResult(text);
    },
  );
}
