import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import {
  computeTotalCommits,
  computeRecentCommits,
  findRepo,
  lastCommitStr,
  textResult,
} from "../types.js";
import {
  readRepos,
  readExclusions,
  readDomainTags,
  filterExcluded,
} from "../data.js";
import { assertAppRunning } from "../lifecycle.js";

export function registerDomainTools(server: McpServer): void {
  server.tool(
    "domain_breakdown",
    "View commit activity broken down by domain (NLP, App Dev, Systems, etc.)",
    {},
    async () => {
      await assertAppRunning();

      const allRepos = readRepos();
      const exclusions = readExclusions();
      const tags = readDomainTags();
      const repos = filterExcluded(allRepos, exclusions);

      if (Object.keys(tags.entries).length === 0) {
        return textResult(
          "No domain tags configured yet. Open ProjectPulse Settings to tag your projects."
        );
      }

      const domainMap = new Map<
        string,
        { commits: number; repoNames: string[] }
      >();

      for (const repo of repos) {
        const entry = tags.entries[repo.path];
        if (!entry || entry.tags.length === 0) continue;

        const recent = computeRecentCommits(repo);

        for (const tag of entry.tags) {
          let info = domainMap.get(tag);
          if (!info) {
            info = { commits: 0, repoNames: [] };
            domainMap.set(tag, info);
          }
          info.commits += recent;
          info.repoNames.push(repo.name);
        }
      }

      if (domainMap.size === 0) {
        return textResult(
          "No domain tags configured yet. Open ProjectPulse Settings to tag your projects."
        );
      }

      const sorted = [...domainMap.entries()].sort(
        (a, b) => b[1].commits - a[1].commits
      );

      const header = "| Domain | 7d Commits | Repos | Repository Names |";
      const sep = "| --- | ---: | ---: | --- |";
      const rows = sorted.map(
        ([domain, info]) =>
          `| ${domain} | ${info.commits} | ${info.repoNames.length} | ${info.repoNames.join(", ")} |`
      );

      return textResult([header, sep, ...rows].join("\n"));
    }
  );

  server.tool(
    "repo_tags",
    "View domain tags assigned to a specific repository",
    {
      repo: z.string().describe("Repository name or path to look up"),
    },
    async ({ repo }) => {
      await assertAppRunning();

      const allRepos = readRepos();
      const tags = readDomainTags();
      const result = findRepo(allRepos, repo);

      if (Array.isArray(result)) {
        const names = result.map((r) => `- ${r.name} (${r.path})`).join("\n");
        return textResult(
          `Multiple repositories match **"${repo}"**. Please be more specific:\n\n${names}`
        );
      }

      if (result === null) {
        return textResult(`No repository found matching **"${repo}"**.`);
      }

      const entry = tags.entries[result.path];
      if (!entry || entry.tags.length === 0) {
        return textResult(`No domain tags assigned to ${result.name}.`);
      }

      const assignment = entry.manual ? "manually set" : "auto-assigned";
      const tagList = entry.tags.map((t) => `- ${t}`).join("\n");
      return textResult(
        `**${result.name}** — tags (${assignment}):\n\n${tagList}`
      );
    }
  );

  server.tool(
    "domain_repos",
    "List all repositories in a specific domain",
    {
      domain: z.string().describe("Domain name (e.g. NLP, App Dev, Systems)"),
    },
    async ({ domain }) => {
      await assertAppRunning();

      const allRepos = readRepos();
      const exclusions = readExclusions();
      const tags = readDomainTags();
      const repos = filterExcluded(allRepos, exclusions);

      const domainLower = domain.toLowerCase();

      const matched = repos.filter((repo) => {
        const entry = tags.entries[repo.path];
        if (!entry) return false;
        return entry.tags.some((t) => t.toLowerCase() === domainLower);
      });

      if (matched.length === 0) {
        return textResult(
          `No repositories found for domain **"${domain}"**.`
        );
      }

      const sorted = [...matched].sort(
        (a, b) => computeRecentCommits(b) - computeRecentCommits(a)
      );

      const header = "| Name | Total Commits | 7d Commits | Last Commit |";
      const sep = "| --- | ---: | ---: | --- |";
      const rows = sorted.map(
        (r) =>
          `| ${r.name} | ${computeTotalCommits(r)} | ${computeRecentCommits(r)} | ${lastCommitStr(r)} |`
      );

      return textResult([header, sep, ...rows].join("\n"));
    }
  );
}
