import { describe, it, expect } from "vitest";
import {
  parseDate,
  formatDate,
  computeTotalCommits,
  computeRecentCommits,
  findRepo,
  lastCommitStr,
  domainStr,
  weekStart,
  dateKey,
  dateFromKey,
  textResult,
} from "../types.js";
import type { RepoInfo, DomainTagsFile } from "../types.js";

describe("parseDate", () => {
  it("returns null for null input", () => {
    expect(parseDate(null)).toBeNull();
  });

  it("parses epoch seconds (Swift format)", () => {
    const d = parseDate(1712534400); // 2024-04-08T00:00:00Z
    expect(d).toBeInstanceOf(Date);
    expect(d!.getFullYear()).toBe(2024);
  });

  it("parses ISO string", () => {
    const d = parseDate("2024-04-08T00:00:00Z");
    expect(d).toBeInstanceOf(Date);
    expect(d!.getFullYear()).toBe(2024);
  });

  it("returns null for invalid string", () => {
    expect(parseDate("not-a-date")).toBeNull();
  });
});

describe("formatDate", () => {
  it("formats date as short US string", () => {
    const d = new Date(2024, 3, 8); // Apr 8, 2024
    const result = formatDate(d);
    expect(result).toContain("Apr");
    expect(result).toContain("8");
    expect(result).toContain("2024");
  });
});

describe("computeTotalCommits", () => {
  it("sums all commit day counts", () => {
    const repo: RepoInfo = {
      path: "/test",
      name: "test",
      lastCommitDate: null,
      commitDays: [
        { date: 1712534400, count: 5 },
        { date: 1712620800, count: 3 },
      ],
    };
    expect(computeTotalCommits(repo)).toBe(8);
  });

  it("returns 0 for empty commit days", () => {
    const repo: RepoInfo = {
      path: "/test",
      name: "test",
      lastCommitDate: null,
      commitDays: [],
    };
    expect(computeTotalCommits(repo)).toBe(0);
  });
});

describe("computeRecentCommits", () => {
  it("counts only commits within the day window", () => {
    const now = new Date();
    const yesterday = new Date(now);
    yesterday.setDate(yesterday.getDate() - 1);
    const twoWeeksAgo = new Date(now);
    twoWeeksAgo.setDate(twoWeeksAgo.getDate() - 14);

    const repo: RepoInfo = {
      path: "/test",
      name: "test",
      lastCommitDate: null,
      commitDays: [
        { date: yesterday.getTime() / 1000, count: 3 },
        { date: twoWeeksAgo.getTime() / 1000, count: 10 },
      ],
    };
    expect(computeRecentCommits(repo, 7)).toBe(3);
  });
});

describe("findRepo", () => {
  const repos: RepoInfo[] = [
    { path: "/Users/x/Projects/alpha", name: "alpha", lastCommitDate: null, commitDays: [] },
    { path: "/Users/x/Projects/beta", name: "beta", lastCommitDate: null, commitDays: [] },
    { path: "/Users/x/Projects/alpha-v2", name: "alpha-v2", lastCommitDate: null, commitDays: [] },
  ];

  it("matches exact path", () => {
    const result = findRepo(repos, "/Users/x/Projects/alpha");
    expect(result).not.toBeNull();
    expect(!Array.isArray(result) && result !== null && result.name).toBe("alpha");
  });

  it("returns single match for unique name", () => {
    const result = findRepo(repos, "beta");
    expect(!Array.isArray(result) && result !== null && result.name).toBe("beta");
  });

  it("returns array for ambiguous match", () => {
    const result = findRepo(repos, "alpha");
    expect(Array.isArray(result)).toBe(true);
    expect((result as RepoInfo[]).length).toBe(2);
  });

  it("returns null for no match", () => {
    expect(findRepo(repos, "gamma")).toBeNull();
  });
});

describe("lastCommitStr", () => {
  it("returns formatted date when present", () => {
    const repo: RepoInfo = {
      path: "/test",
      name: "test",
      lastCommitDate: 1712534400,
      commitDays: [],
    };
    const result = lastCommitStr(repo);
    expect(result).toContain("2024");
  });

  it("returns dash when null", () => {
    const repo: RepoInfo = {
      path: "/test",
      name: "test",
      lastCommitDate: null,
      commitDays: [],
    };
    expect(lastCommitStr(repo)).toBe("—");
  });
});

describe("domainStr", () => {
  it("returns joined tags", () => {
    const tags: DomainTagsFile = {
      entries: { "/test": { tags: ["NLP", "App Dev"], manual: false } },
      customTags: [],
    };
    expect(domainStr("/test", tags)).toBe("NLP, App Dev");
  });

  it("returns dash when no tags", () => {
    const tags: DomainTagsFile = { entries: {}, customTags: [] };
    expect(domainStr("/test", tags)).toBe("—");
  });
});

describe("weekStart", () => {
  it("returns Monday for a Wednesday", () => {
    const wed = new Date(2024, 3, 10); // Apr 10 2024 = Wednesday
    const monday = weekStart(wed);
    expect(monday.getDay()).toBe(1); // Monday
    expect(monday.getDate()).toBe(8);
  });

  it("returns Monday for a Sunday", () => {
    const sun = new Date(2024, 3, 14); // Apr 14 2024 = Sunday
    const monday = weekStart(sun);
    expect(monday.getDay()).toBe(1);
    expect(monday.getDate()).toBe(8);
  });

  it("returns same day for a Monday", () => {
    const mon = new Date(2024, 3, 8); // Apr 8 2024 = Monday
    const result = weekStart(mon);
    expect(result.getDate()).toBe(8);
  });
});

describe("dateKey / dateFromKey", () => {
  it("round-trips a date", () => {
    const d = new Date(2024, 3, 8);
    const key = dateKey(d);
    expect(key).toBe("2024-04-08");
    const back = dateFromKey(key);
    expect(back.getFullYear()).toBe(2024);
    expect(back.getMonth()).toBe(3);
    expect(back.getDate()).toBe(8);
  });
});

describe("textResult", () => {
  it("wraps text in MCP content format", () => {
    const result = textResult("hello");
    expect(result).toEqual({
      content: [{ type: "text", text: "hello" }],
    });
  });
});
