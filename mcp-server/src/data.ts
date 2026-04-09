import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import type {
  RepoInfo,
  AppSettings,
  DomainTagsFile,
} from "./types.js";
import { DEFAULT_SETTINGS } from "./types.js";

const DATA_DIR = path.join(
  os.homedir(),
  "Library/Application Support/ProjectPulse"
);

function readJsonFile<T>(filename: string): T | null {
  const filePath = path.join(DATA_DIR, filename);
  try {
    const raw = fs.readFileSync(filePath, "utf-8");
    return JSON.parse(raw) as T;
  } catch (err) {
    if (err instanceof SyntaxError) {
      throw new Error(`Failed to parse ${filename}: invalid JSON. Try relaunching ProjectPulse.`);
    }
    // File missing or unreadable — return null
    return null;
  }
}

export function readRepos(): RepoInfo[] {
  const data = readJsonFile<RepoInfo[]>("repos.json");
  return data ?? [];
}

export function readSettings(): AppSettings {
  const data = readJsonFile<Partial<AppSettings>>("settings.json");
  if (!data) return { ...DEFAULT_SETTINGS };
  return { ...DEFAULT_SETTINGS, ...data };
}

export function readDomainTags(): DomainTagsFile {
  const data = readJsonFile<DomainTagsFile>("domain-tags.json");
  return data ?? { entries: {}, customTags: [] };
}

export function readExclusions(): Set<string> {
  const data = readJsonFile<string[]>("exclusions.json");
  return new Set(data ?? []);
}

export function filterExcluded(
  repos: RepoInfo[],
  exclusions: Set<string>
): RepoInfo[] {
  return repos.filter((r) => !exclusions.has(r.path));
}

export function getFileMtime(filename: string): Date | null {
  const filePath = path.join(DATA_DIR, filename);
  try {
    const stat = fs.statSync(filePath);
    return stat.mtime;
  } catch {
    return null;
  }
}
