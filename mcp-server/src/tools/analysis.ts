import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import {
  parseDate,
  computeTotalCommits,
  computeRecentCommits,
  findRepo,
  lastCommitStr,
  domainStr,
  weekStart,
  textResult,
} from "../types.js";
import type { RepoInfo, DomainTagsFile } from "../types.js";
import {
  readRepos,
  readExclusions,
  readDomainTags,
  filterExcluded,
} from "../data.js";
import { assertAppRunning } from "../lifecycle.js";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Build a map of weekStart-timestamp → total commits for a repo. */
function weeklyTotals(
  repo: RepoInfo,
  weeks: number,
): Map<number, number> {
  const now = new Date();
  const cutoff = new Date(now);
  cutoff.setDate(cutoff.getDate() - weeks * 7);
  cutoff.setHours(0, 0, 0, 0);

  const map = new Map<number, number>();
  for (const cd of repo.commitDays) {
    const d = parseDate(cd.date);
    if (!d || d < cutoff) continue;
    const ws = weekStart(d).getTime();
    map.set(ws, (map.get(ws) ?? 0) + cd.count);
  }
  return map;
}

/** Generate ordered week-start timestamps for the last N weeks. */
function lastNWeekStarts(weeks: number): number[] {
  const now = new Date();
  const currentWeek = weekStart(now);
  const starts: number[] = [];
  for (let i = weeks - 1; i >= 0; i--) {
    const ws = new Date(currentWeek);
    ws.setDate(ws.getDate() - i * 7);
    starts.push(ws.getTime());
  }
  return starts;
}

function sparkChar(value: number, max: number): string {
  if (max === 0) return "░";
  const ratio = value / max;
  if (ratio >= 0.9) return "█";
  if (ratio >= 0.55) return "▓";
  if (ratio >= 0.2) return "▒";
  return "░";
}

function formatWeekLabel(ts: number): string {
  const d = new Date(ts);
  return d.toLocaleDateString("en-US", { month: "short", day: "numeric" });
}

// ---------------------------------------------------------------------------
// Tool registration
// ---------------------------------------------------------------------------

export function registerAnalysisTools(server: McpServer): void {
  // ---- compare_repos -----------------------------------------------------
  server.tool(
    "compare_repos",
    "Compare activity between two or more repositories side by side",
    {
      repos: z
        .array(z.string())
        .min(2)
        .max(5)
        .describe("Repository names or paths to compare (2–5)"),
    },
    async ({ repos: repoQueries }) => {
      await assertAppRunning();

      const allRepos = readRepos();
      const tags = readDomainTags();

      const notFound: string[] = [];
      const ambiguous: { query: string; matches: RepoInfo[] }[] = [];
      const resolved: RepoInfo[] = [];

      for (const q of repoQueries) {
        const result = findRepo(allRepos, q);
        if (result === null) {
          notFound.push(q);
        } else if (Array.isArray(result)) {
          ambiguous.push({ query: q, matches: result });
        } else {
          resolved.push(result);
        }
      }

      if (notFound.length > 0 || ambiguous.length > 0) {
        const parts: string[] = [];
        if (notFound.length > 0) {
          parts.push(`Not found: ${notFound.map((n) => `"${n}"`).join(", ")}`);
        }
        for (const a of ambiguous) {
          const names = a.matches
            .map((r) => `- ${r.name} (${r.path})`)
            .join("\n");
          parts.push(
            `Ambiguous "${a.query}" — matches:\n${names}`,
          );
        }
        return {
          content: [{ type: "text", text: parts.join("\n\n") }],
          isError: true,
        };
      }

      // Build comparison table
      const header =
        "| Name | Total Commits | 7d Commits | Last Commit | Domains |";
      const sep = "| --- | ---: | ---: | --- | --- |";
      const rows = resolved.map(
        (r) =>
          `| ${r.name} | ${computeTotalCommits(r)} | ${computeRecentCommits(r)} | ${lastCommitStr(r)} | ${domainStr(r.path, tags)} |`,
      );

      // 4-week sparklines
      const weeks = 4;
      const weekStarts = lastNWeekStarts(weeks);

      const sparkLines: string[] = [];
      for (const repo of resolved) {
        const wt = weeklyTotals(repo, weeks);
        const values = weekStarts.map((ws) => wt.get(ws) ?? 0);
        const max = Math.max(...values);
        const spark = values.map((v) => sparkChar(v, max)).join("");
        sparkLines.push(`${repo.name}: ${spark}`);
      }

      const weekLabels = weekStarts
        .map((ws) => formatWeekLabel(ws))
        .join(" → ");

      const text = [
        "## Repository Comparison",
        "",
        header,
        sep,
        ...rows,
        "",
        "### 4-Week Activity Sparklines",
        "",
        `Weeks: ${weekLabels}`,
        "",
        "```",
        ...sparkLines,
        "```",
      ].join("\n");

      return { content: [{ type: "text", text }] };
    },
  );

  // ---- trend_analysis ----------------------------------------------------
  server.tool(
    "trend_analysis",
    "Analyze commit activity trends over recent weeks",
    {
      weeks: z
        .number()
        .min(2)
        .max(12)
        .default(4)
        .describe("Number of weeks to analyze (default: 4)"),
    },
    async ({ weeks }) => {
      await assertAppRunning();

      const allRepos = readRepos();
      const exclusions = readExclusions();
      const repos = filterExcluded(allRepos, exclusions);

      // Aggregate all commit days into weekly buckets
      const weekStarts = lastNWeekStarts(weeks);
      const weekTotals = new Map<number, number>();
      for (const ws of weekStarts) {
        weekTotals.set(ws, 0);
      }

      for (const repo of repos) {
        const wt = weeklyTotals(repo, weeks);
        for (const [ws, count] of wt) {
          // Only count weeks in our range
          if (weekTotals.has(ws)) {
            weekTotals.set(ws, (weekTotals.get(ws) ?? 0) + count);
          }
        }
      }

      // Build weekly totals in order
      const orderedTotals = weekStarts.map((ws) => ({
        weekStart: ws,
        total: weekTotals.get(ws) ?? 0,
      }));

      // Compute week-over-week changes
      const changes: string[] = [];
      for (let i = 1; i < orderedTotals.length; i++) {
        const prev = orderedTotals[i - 1].total;
        const curr = orderedTotals[i].total;
        if (prev === 0) {
          changes.push(curr === 0 ? "0%" : "+∞%");
        } else {
          const pct = ((curr - prev) / prev) * 100;
          const sign = pct >= 0 ? "+" : "";
          changes.push(`${sign}${pct.toFixed(1)}%`);
        }
      }

      // Trend direction: last week vs average of prior weeks
      const lastWeek = orderedTotals[orderedTotals.length - 1].total;
      const priorWeeks = orderedTotals.slice(0, -1);
      const priorAvg =
        priorWeeks.length > 0
          ? priorWeeks.reduce((s, w) => s + w.total, 0) / priorWeeks.length
          : 0;

      let trend: string;
      if (priorAvg === 0) {
        trend = lastWeek > 0 ? "increasing" : "stable";
      } else {
        const pctDiff = ((lastWeek - priorAvg) / priorAvg) * 100;
        if (pctDiff > 10) trend = "increasing";
        else if (pctDiff < -10) trend = "decreasing";
        else trend = "stable";
      }

      // Build table
      const tableHeader = "| Week Starting | Commits | Change |";
      const tableSep = "| --- | ---: | ---: |";
      const tableRows = orderedTotals.map((w, i) => {
        const label = formatWeekLabel(w.weekStart);
        const change = i === 0 ? "—" : changes[i - 1];
        return `| ${label} | ${w.total} | ${change} |`;
      });

      const totalCommits = orderedTotals.reduce((s, w) => s + w.total, 0);
      const avgPerWeek =
        orderedTotals.length > 0
          ? (totalCommits / orderedTotals.length).toFixed(1)
          : "0";

      const text = [
        `## Commit Trend Analysis (${weeks} weeks)`,
        "",
        tableHeader,
        tableSep,
        ...tableRows,
        "",
        "### Summary",
        "",
        `- **Trend:** ${trend}`,
        `- **Total commits:** ${totalCommits}`,
        `- **Average per week:** ${avgPerWeek}`,
        `- **Last week:** ${lastWeek} commits`,
        `- **Prior weeks average:** ${priorAvg.toFixed(1)} commits`,
      ].join("\n");

      return { content: [{ type: "text", text }] };
    },
  );
}
