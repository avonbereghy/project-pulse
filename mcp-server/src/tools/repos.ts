import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import {
  parseDate,
  formatDate,
  computeTotalCommits,
  computeRecentCommits,
  findRepo,
  lastCommitStr,
  domainStr,
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

function domainStrDetailed(path: string, tags: DomainTagsFile): string {
  const entry = tags.entries[path];
  if (!entry || entry.tags.length === 0) return "None";
  const suffix = entry.manual ? " (manual)" : " (auto)";
  return entry.tags.join(", ") + suffix;
}

function repoTableRow(
  repo: RepoInfo,
  tags: DomainTagsFile,
): string {
  return `| ${repo.name} | ${computeTotalCommits(repo)} | ${computeRecentCommits(repo)} | ${lastCommitStr(repo)} | ${domainStr(repo.path, tags)} |`;
}

function repoTable(repos: RepoInfo[], tags: DomainTagsFile): string {
  const header = "| Name | Total Commits | 7d Commits | Last Commit | Domains |";
  const sep = "| --- | ---: | ---: | --- | --- |";
  const rows = repos.map((r) => repoTableRow(r, tags));
  return [header, sep, ...rows].join("\n");
}

type SortKey = "name" | "total_commits" | "recent_commits" | "last_commit";

function sortRepos(repos: RepoInfo[], key: SortKey): RepoInfo[] {
  const sorted = [...repos];
  switch (key) {
    case "name":
      sorted.sort((a, b) => a.name.localeCompare(b.name));
      break;
    case "total_commits":
      sorted.sort((a, b) => computeTotalCommits(b) - computeTotalCommits(a));
      break;
    case "recent_commits":
      sorted.sort((a, b) => computeRecentCommits(b) - computeRecentCommits(a));
      break;
    case "last_commit": {
      sorted.sort((a, b) => {
        const da = parseDate(a.lastCommitDate)?.getTime() ?? 0;
        const db = parseDate(b.lastCommitDate)?.getTime() ?? 0;
        return db - da;
      });
      break;
    }
  }
  return sorted;
}

// ---------------------------------------------------------------------------
// Tool registration
// ---------------------------------------------------------------------------

export function registerRepoTools(server: McpServer): void {
  // ---- list_repos --------------------------------------------------------
  server.tool(
    "list_repos",
    "List all tracked repositories with commit statistics and domain tags",
    {
      sort_by: z
        .enum(["name", "total_commits", "recent_commits", "last_commit"])
        .optional()
        .describe("Field to sort by (default: recent_commits)"),
      limit: z.number().optional().describe("Maximum number of repos to return"),
      include_excluded: z
        .boolean()
        .optional()
        .describe("Include excluded repositories (default: false)"),
    },
    async ({ sort_by, limit, include_excluded }) => {
      await assertAppRunning();

      const allRepos = readRepos();
      const exclusions = readExclusions();
      const tags = readDomainTags();

      let repos =
        include_excluded ? allRepos : filterExcluded(allRepos, exclusions);
      repos = sortRepos(repos, sort_by ?? "recent_commits");
      if (limit !== undefined) {
        repos = repos.slice(0, limit);
      }

      const text =
        repos.length === 0
          ? "No repositories found."
          : repoTable(repos, tags);

      return { content: [{ type: "text", text }] };
    },
  );

  // ---- get_repo ----------------------------------------------------------
  server.tool(
    "get_repo",
    "Get detailed information about a specific repository",
    {
      repo: z.string().describe("Repository name or path to look up"),
    },
    async ({ repo }) => {
      await assertAppRunning();

      const allRepos = readRepos();
      const exclusions = readExclusions();
      const tags = readDomainTags();
      const result = findRepo(allRepos, repo);

      // Ambiguous
      if (Array.isArray(result)) {
        const names = result.map((r) => `- ${r.name} (${r.path})`).join("\n");
        return {
          content: [
            {
              type: "text",
              text: `Multiple repositories match **"${repo}"**. Please be more specific:\n\n${names}`,
            },
          ],
        };
      }

      // Not found
      if (result === null) {
        return {
          content: [
            {
              type: "text",
              text: `No repository found matching **"${repo}"**.`,
            },
          ],
        };
      }

      // Single match — build detailed view
      const r = result;
      const total = computeTotalCommits(r);
      const recent = computeRecentCommits(r);
      const lastDate = lastCommitStr(r);
      const domains = domainStrDetailed(r.path, tags);
      const excluded = exclusions.has(r.path) ? "Yes" : "No";

      // Last 30 days commit history
      const cutoff = new Date();
      cutoff.setDate(cutoff.getDate() - 30);
      cutoff.setHours(0, 0, 0, 0);

      const recentDays = r.commitDays
        .map((d) => ({ date: parseDate(d.date), count: d.count }))
        .filter((d): d is { date: Date; count: number } => d.date !== null && d.date >= cutoff)
        .sort((a, b) => b.date.getTime() - a.date.getTime());

      const historyLines =
        recentDays.length === 0
          ? "No commits in the last 30 days."
          : recentDays
              .map((d) => `- ${formatDate(d.date)}: ${d.count} commit${d.count === 1 ? "" : "s"}`)
              .join("\n");

      const text = [
        `## ${r.name}`,
        "",
        `**Path:** \`${r.path}\``,
        `**Total commits:** ${total}`,
        `**7-day commits:** ${recent}`,
        `**Last commit:** ${lastDate}`,
        `**Domains:** ${domains}`,
        `**Excluded:** ${excluded}`,
        "",
        "### Last 30 days",
        "",
        historyLines,
      ].join("\n");

      return { content: [{ type: "text", text }] };
    },
  );

  // ---- search_repos ------------------------------------------------------
  server.tool(
    "search_repos",
    "Search repositories by name or path",
    {
      query: z.string().describe("Search term (case-insensitive substring match on name and path)"),
    },
    async ({ query }) => {
      await assertAppRunning();

      const allRepos = readRepos();
      const tags = readDomainTags();
      const lower = query.toLowerCase();

      const matches = allRepos.filter(
        (r) =>
          r.name.toLowerCase().includes(lower) ||
          r.path.toLowerCase().includes(lower),
      );

      const text =
        matches.length === 0
          ? `No repositories matching **"${query}"**.`
          : repoTable(matches, tags);

      return { content: [{ type: "text", text }] };
    },
  );
}
