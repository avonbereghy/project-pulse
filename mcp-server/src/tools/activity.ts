import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import {
  parseDate,
  formatDate,
  computeRecentCommits,
  findRepo,
} from "../types.js";
import type { RepoInfo, CommitDay } from "../types.js";
import { readRepos, readExclusions, filterExcluded } from "../data.js";
import { assertAppRunning } from "../lifecycle.js";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Return a Date for the start of the ISO week (Monday) containing `d`. */
function weekStart(d: Date): Date {
  const copy = new Date(d);
  copy.setHours(0, 0, 0, 0);
  const day = copy.getDay(); // 0=Sun … 6=Sat
  const diff = day === 0 ? 6 : day - 1; // distance back to Monday
  copy.setDate(copy.getDate() - diff);
  return copy;
}

/** Build a Map<dateKey, totalCommits> across the given repos. */
function aggregateCommitMap(repos: RepoInfo[]): Map<string, number> {
  const map = new Map<string, number>();
  for (const repo of repos) {
    for (const cd of repo.commitDays) {
      const d = parseDate(cd.date);
      if (!d) continue;
      const key = dateKey(d);
      map.set(key, (map.get(key) ?? 0) + cd.count);
    }
  }
  return map;
}

function dateKey(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

function dateFromKey(key: string): Date {
  const [y, m, d] = key.split("-").map(Number);
  return new Date(y, m - 1, d);
}

const DAY_NAMES = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

function shortDate(d: Date): string {
  const day = DAY_NAMES[d.getDay()];
  const month = d.toLocaleDateString("en-US", { month: "short" });
  return `${day}, ${month} ${d.getDate()}`;
}

function loadRepos(): RepoInfo[] {
  const repos = readRepos();
  const exclusions = readExclusions();
  return filterExcluded(repos, exclusions);
}

function textResult(text: string) {
  return { content: [{ type: "text" as const, text }] };
}

/** Compute current streak (consecutive days with >=1 commit, counting backward). */
function currentStreak(commitMap: Map<string, number>): number {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  let cursor = new Date(today);
  // If today has no commits, start from yesterday
  if (!commitMap.get(dateKey(cursor))) {
    cursor.setDate(cursor.getDate() - 1);
  }

  let streak = 0;
  while (true) {
    const count = commitMap.get(dateKey(cursor)) ?? 0;
    if (count === 0) break;
    streak++;
    cursor.setDate(cursor.getDate() - 1);
  }
  return streak;
}

/** Scan full data range for the longest consecutive run. */
function longestStreak(commitMap: Map<string, number>): number {
  if (commitMap.size === 0) return 0;

  const sortedKeys = [...commitMap.keys()].sort();
  const first = dateFromKey(sortedKeys[0]);
  const last = dateFromKey(sortedKeys[sortedKeys.length - 1]);

  let longest = 0;
  let run = 0;
  const cursor = new Date(first);
  while (cursor <= last) {
    const count = commitMap.get(dateKey(cursor)) ?? 0;
    if (count > 0) {
      run++;
      if (run > longest) longest = run;
    } else {
      run = 0;
    }
    cursor.setDate(cursor.getDate() + 1);
  }
  return longest;
}

// ---------------------------------------------------------------------------
// Registration
// ---------------------------------------------------------------------------

export function registerActivityTools(server: McpServer): void {
  // -----------------------------------------------------------------------
  // activity_summary
  // -----------------------------------------------------------------------
  server.tool(
    "activity_summary",
    "Get an overview of your coding activity across all repositories",
    {},
    async () => {
      await assertAppRunning();
      const repos = loadRepos();

      const totalRepos = repos.length;
      let totalCommits = 0;
      for (const r of repos) {
        for (const cd of r.commitDays) totalCommits += cd.count;
      }

      // Commits this week (Mon-Sun of current week)
      const now = new Date();
      const monStart = weekStart(now);
      const sunEnd = new Date(monStart);
      sunEnd.setDate(sunEnd.getDate() + 7); // exclusive upper bound

      const commitMap = aggregateCommitMap(repos);

      let weekCommits = 0;
      const cursor = new Date(monStart);
      while (cursor < sunEnd) {
        weekCommits += commitMap.get(dateKey(cursor)) ?? 0;
        cursor.setDate(cursor.getDate() + 1);
      }

      // Most active day in last 7 days
      const sevenDaysAgo = new Date(now);
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 6);
      sevenDaysAgo.setHours(0, 0, 0, 0);

      let bestDay = "";
      let bestCount = 0;
      const dayCursor = new Date(sevenDaysAgo);
      for (let i = 0; i < 7; i++) {
        const count = commitMap.get(dateKey(dayCursor)) ?? 0;
        if (count > bestCount) {
          bestCount = count;
          bestDay = DAY_NAMES[dayCursor.getDay()];
        }
        dayCursor.setDate(dayCursor.getDate() + 1);
      }

      // Current streak
      const streak = currentStreak(commitMap);

      // Top 5 repos by 7d commits
      const reposByRecent = repos
        .map((r) => ({ name: r.name, recent: computeRecentCommits(r, 7) }))
        .sort((a, b) => b.recent - a.recent)
        .slice(0, 5);

      const top5Lines = reposByRecent
        .map((r, i) => `  ${i + 1}. ${r.name} — ${r.recent} commits`)
        .join("\n");

      const text = [
        "=== Activity Summary ===",
        "",
        `Repositories tracked:  ${totalRepos}`,
        `Total commits (all time): ${totalCommits}`,
        `Commits this week:     ${weekCommits}`,
        `Most active day (7d):  ${bestDay || "N/A"} (${bestCount} commits)`,
        `Current streak:        ${streak} day${streak !== 1 ? "s" : ""}`,
        "",
        "Top 5 repos (last 7 days):",
        top5Lines || "  (no recent activity)",
      ].join("\n");

      return textResult(text);
    }
  );

  // -----------------------------------------------------------------------
  // commit_history
  // -----------------------------------------------------------------------
  server.tool(
    "commit_history",
    "View daily commit counts for a repository or across all repositories",
    {
      repo: z
        .string()
        .optional()
        .describe("Repository name or path (omit for all repos)"),
      days: z
        .number()
        .int()
        .positive()
        .optional()
        .describe("Number of days to show (default 30)"),
    },
    async ({ repo, days }) => {
      await assertAppRunning();
      const allRepos = loadRepos();
      const numDays = days ?? 30;

      let targetRepos: RepoInfo[];
      if (repo) {
        const result = findRepo(allRepos, repo);
        if (result === null) {
          return textResult(`No repository matching "${repo}" found.`);
        }
        if (Array.isArray(result)) {
          const names = result.map((r) => `  - ${r.name} (${r.path})`).join("\n");
          return textResult(
            `Ambiguous query "${repo}". Did you mean one of:\n${names}`
          );
        }
        targetRepos = [result];
      } else {
        targetRepos = allRepos;
      }

      const commitMap = aggregateCommitMap(targetRepos);

      const today = new Date();
      today.setHours(0, 0, 0, 0);

      const lines: string[] = [];
      const heading = repo
        ? `Commit history for "${targetRepos[0].name}" (last ${numDays} days)`
        : `Aggregate commit history (last ${numDays} days)`;
      lines.push(heading);
      lines.push("");

      const cur = new Date(today);
      for (let i = 0; i < numDays; i++) {
        const count = commitMap.get(dateKey(cur)) ?? 0;
        const label = shortDate(cur);
        lines.push(`${label}: ${count} commit${count !== 1 ? "s" : ""}`);
        cur.setDate(cur.getDate() - 1);
      }

      return textResult(lines.join("\n"));
    }
  );

  // -----------------------------------------------------------------------
  // streak_analysis
  // -----------------------------------------------------------------------
  server.tool(
    "streak_analysis",
    "Analyze your commit streak and consistency patterns",
    {},
    async () => {
      await assertAppRunning();
      const repos = loadRepos();
      const commitMap = aggregateCommitMap(repos);

      const current = currentStreak(commitMap);
      const longest = longestStreak(commitMap);

      // Gap days in last 30 days
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const gaps: string[] = [];
      const cur = new Date(today);
      for (let i = 0; i < 30; i++) {
        const count = commitMap.get(dateKey(cur)) ?? 0;
        if (count === 0) {
          gaps.push(shortDate(cur));
        }
        cur.setDate(cur.getDate() - 1);
      }

      const gapExamples =
        gaps.length > 0
          ? gaps.slice(0, 5).join(", ") +
            (gaps.length > 5 ? `, … and ${gaps.length - 5} more` : "")
          : "none";

      const text = [
        "=== Streak Analysis ===",
        "",
        `Current streak:   ${current} day${current !== 1 ? "s" : ""}`,
        `Longest streak:   ${longest} day${longest !== 1 ? "s" : ""}`,
        "",
        `Gap days (last 30 days): ${gaps.length}`,
        `  Examples: ${gapExamples}`,
        "",
        `Active days (last 30): ${30 - gaps.length}/30`,
        `Consistency rate:      ${Math.round(((30 - gaps.length) / 30) * 100)}%`,
      ].join("\n");

      return textResult(text);
    }
  );

  // -----------------------------------------------------------------------
  // weekly_report
  // -----------------------------------------------------------------------
  server.tool(
    "weekly_report",
    "Compare this week's activity against last week",
    {},
    async () => {
      await assertAppRunning();
      const repos = loadRepos();
      const commitMap = aggregateCommitMap(repos);

      const now = new Date();
      const thisMonday = weekStart(now);
      const lastMonday = new Date(thisMonday);
      lastMonday.setDate(lastMonday.getDate() - 7);

      // Determine how many days into the current week (Mon=0 .. Sun=6)
      const dayOfWeek = now.getDay();
      const daysIntoWeek = dayOfWeek === 0 ? 7 : dayOfWeek; // Mon=1..Sun=7

      // Build per-day breakdown for both weeks
      const dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
      let thisWeekTotal = 0;
      let lastWeekTotal = 0;

      const rows: string[] = [];
      rows.push(
        `${"Day".padEnd(5)} ${"This Week".padStart(10)} ${"Last Week".padStart(10)}`
      );
      rows.push("-".repeat(27));

      for (let i = 0; i < 7; i++) {
        const thisDay = new Date(thisMonday);
        thisDay.setDate(thisDay.getDate() + i);
        const lastDay = new Date(lastMonday);
        lastDay.setDate(lastDay.getDate() + i);

        const thisCount =
          i < daysIntoWeek ? commitMap.get(dateKey(thisDay)) ?? 0 : 0;
        const lastCount = commitMap.get(dateKey(lastDay)) ?? 0;

        thisWeekTotal += thisCount;
        lastWeekTotal += lastCount;

        const thisFmt = i < daysIntoWeek ? String(thisCount) : "-";
        rows.push(
          `${dayLabels[i].padEnd(5)} ${thisFmt.padStart(10)} ${String(lastCount).padStart(10)}`
        );
      }

      rows.push("-".repeat(27));
      rows.push(
        `${"Total".padEnd(5)} ${String(thisWeekTotal).padStart(10)} ${String(lastWeekTotal).padStart(10)}`
      );

      // Percentage change
      let changeStr: string;
      if (lastWeekTotal === 0) {
        changeStr = thisWeekTotal > 0 ? "+Infinity%" : "0%";
      } else {
        const pct = ((thisWeekTotal - lastWeekTotal) / lastWeekTotal) * 100;
        const sign = pct >= 0 ? "+" : "";
        changeStr = `${sign}${pct.toFixed(1)}%`;
      }

      // Most active repo this week
      const reposByRecent = repos
        .map((r) => ({ name: r.name, recent: computeRecentCommits(r, 7) }))
        .sort((a, b) => b.recent - a.recent);
      const topRepo =
        reposByRecent.length > 0 && reposByRecent[0].recent > 0
          ? `${reposByRecent[0].name} (${reposByRecent[0].recent} commits)`
          : "N/A";

      const text = [
        "=== Weekly Report ===",
        "",
        ...rows,
        "",
        `Change from last week: ${changeStr}`,
        `Most active repo (7d): ${topRepo}`,
      ].join("\n");

      return textResult(text);
    }
  );
}
