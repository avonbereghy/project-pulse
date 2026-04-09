import os from "node:os";

// --- Interfaces matching Swift data models ---

export interface CommitDay {
  date: number | string; // Swift JSONEncoder writes seconds-since-epoch (number)
  count: number;
}

export interface RepoInfo {
  path: string;
  name: string;
  lastCommitDate: number | string | null; // seconds-since-epoch or ISO string
  commitDays: CommitDay[];
}

export interface DomainTagEntry {
  tags: string[];
  manual: boolean;
}

export interface DomainTagsFile {
  entries: Record<string, DomainTagEntry>;
  customTags: string[];
}

export interface AppSettings {
  displayCount: number;
  dayRange: number;
  scanDepth: number;
  scanRoot: string;
  authorEmails: string[];
  sortField: string;
  sortAscending: boolean;
  windowOpacity: number;
  showMenuBar: boolean;
  rescanIntervalMinutes: number;
}

// --- Defaults ---

export const DEFAULT_SETTINGS: AppSettings = {
  displayCount: 10,
  dayRange: 90,
  scanDepth: 5,
  scanRoot: os.homedir() + "/Projects",
  authorEmails: [],
  sortField: "7d Commits",
  sortAscending: false,
  windowOpacity: 1.0,
  showMenuBar: true,
  rescanIntervalMinutes: 45,
};

// --- Helpers ---

export function parseDate(value: number | string | null): Date | null {
  if (value === null || value === undefined) return null;
  if (typeof value === "number") {
    // Swift JSONEncoder writes seconds-since-epoch
    return new Date(value * 1000);
  }
  const d = new Date(value);
  return isNaN(d.getTime()) ? null : d;
}

export function formatDate(date: Date): string {
  return date.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

export function computeTotalCommits(repo: RepoInfo): number {
  return repo.commitDays.reduce((sum, d) => sum + d.count, 0);
}

export function computeRecentCommits(repo: RepoInfo, days = 7): number {
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - days);
  cutoff.setHours(0, 0, 0, 0);
  return repo.commitDays
    .filter((d) => {
      const date = parseDate(d.date);
      return date !== null && date >= cutoff;
    })
    .reduce((sum, d) => sum + d.count, 0);
}

/**
 * Find a repo by name or path. Returns:
 * - Single RepoInfo if exact path match or single name match
 * - Array if multiple name matches (ambiguous)
 * - null if no match
 */
export function lastCommitStr(repo: RepoInfo): string {
  const d = parseDate(repo.lastCommitDate);
  return d ? formatDate(d) : "—";
}

export function domainStr(
  repoPath: string,
  tags: DomainTagsFile
): string {
  const entry = tags.entries[repoPath];
  if (!entry || entry.tags.length === 0) return "—";
  return entry.tags.join(", ");
}

/** Return the Monday 00:00 local time for the ISO week containing `d`. */
export function weekStart(d: Date): Date {
  const copy = new Date(d);
  copy.setHours(0, 0, 0, 0);
  const day = copy.getDay(); // 0=Sun … 6=Sat
  const diff = day === 0 ? 6 : day - 1;
  copy.setDate(copy.getDate() - diff);
  return copy;
}

export function dateKey(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

export function dateFromKey(key: string): Date {
  const [y, m, d] = key.split("-").map(Number);
  return new Date(y, m - 1, d);
}

export function textResult(text: string) {
  return { content: [{ type: "text" as const, text }] };
}

export function findRepo(
  repos: RepoInfo[],
  query: string
): RepoInfo | RepoInfo[] | null {
  // Exact path match first
  const exactPath = repos.find((r) => r.path === query);
  if (exactPath) return exactPath;

  // Case-insensitive name substring match
  const lower = query.toLowerCase();
  const matches = repos.filter(
    (r) =>
      r.name.toLowerCase().includes(lower) ||
      r.path.toLowerCase().includes(lower)
  );

  if (matches.length === 0) return null;
  if (matches.length === 1) return matches[0];
  return matches;
}
