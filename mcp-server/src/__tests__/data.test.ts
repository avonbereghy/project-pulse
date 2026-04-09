import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import fs from "node:fs";
import { readRepos, readSettings, readDomainTags, readExclusions, filterExcluded, getFileMtime } from "../data.js";
import { DEFAULT_SETTINGS } from "../types.js";
import type { RepoInfo } from "../types.js";

// Mock fs to avoid touching real filesystem
vi.mock("node:fs");

beforeEach(() => {
  vi.restoreAllMocks();
});

describe("readRepos", () => {
  it("returns parsed repos from JSON", () => {
    const mockRepos = [
      { path: "/test", name: "test", lastCommitDate: null, commitDays: [] },
    ];
    vi.mocked(fs.readFileSync).mockReturnValue(JSON.stringify(mockRepos));
    const result = readRepos();
    expect(result).toEqual(mockRepos);
  });

  it("returns empty array when file missing", () => {
    vi.mocked(fs.readFileSync).mockImplementation(() => {
      throw new Error("ENOENT");
    });
    expect(readRepos()).toEqual([]);
  });

  it("throws on invalid JSON", () => {
    vi.mocked(fs.readFileSync).mockReturnValue("{invalid json");
    expect(() => readRepos()).toThrow("Failed to parse");
  });
});

describe("readSettings", () => {
  it("merges partial settings with defaults", () => {
    vi.mocked(fs.readFileSync).mockReturnValue(
      JSON.stringify({ dayRange: 30 })
    );
    const result = readSettings();
    expect(result.dayRange).toBe(30);
    expect(result.displayCount).toBe(DEFAULT_SETTINGS.displayCount);
  });

  it("returns defaults when file missing", () => {
    vi.mocked(fs.readFileSync).mockImplementation(() => {
      throw new Error("ENOENT");
    });
    const result = readSettings();
    expect(result.dayRange).toBe(90);
  });
});

describe("readDomainTags", () => {
  it("returns parsed domain tags", () => {
    const mock = {
      entries: { "/test": { tags: ["NLP"], manual: false } },
      customTags: [],
    };
    vi.mocked(fs.readFileSync).mockReturnValue(JSON.stringify(mock));
    expect(readDomainTags()).toEqual(mock);
  });

  it("returns empty structure when file missing", () => {
    vi.mocked(fs.readFileSync).mockImplementation(() => {
      throw new Error("ENOENT");
    });
    const result = readDomainTags();
    expect(result.entries).toEqual({});
    expect(result.customTags).toEqual([]);
  });
});

describe("readExclusions", () => {
  it("returns Set of excluded paths", () => {
    vi.mocked(fs.readFileSync).mockReturnValue(JSON.stringify(["/old"]));
    const result = readExclusions();
    expect(result.has("/old")).toBe(true);
    expect(result.size).toBe(1);
  });

  it("returns empty Set when file missing", () => {
    vi.mocked(fs.readFileSync).mockImplementation(() => {
      throw new Error("ENOENT");
    });
    expect(readExclusions().size).toBe(0);
  });
});

describe("filterExcluded", () => {
  it("removes repos in exclusion set", () => {
    const repos: RepoInfo[] = [
      { path: "/keep", name: "keep", lastCommitDate: null, commitDays: [] },
      { path: "/skip", name: "skip", lastCommitDate: null, commitDays: [] },
    ];
    const exclusions = new Set(["/skip"]);
    const result = filterExcluded(repos, exclusions);
    expect(result).toHaveLength(1);
    expect(result[0].name).toBe("keep");
  });
});

describe("getFileMtime", () => {
  it("returns mtime when file exists", () => {
    const mockDate = new Date("2024-04-08T12:00:00Z");
    vi.mocked(fs.statSync).mockReturnValue({ mtime: mockDate } as fs.Stats);
    expect(getFileMtime("repos.json")).toEqual(mockDate);
  });

  it("returns null when file missing", () => {
    vi.mocked(fs.statSync).mockImplementation(() => {
      throw new Error("ENOENT");
    });
    expect(getFileMtime("repos.json")).toBeNull();
  });
});
