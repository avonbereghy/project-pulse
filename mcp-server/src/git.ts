import { execFile } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import type { CommitDay, AppSettings } from "./types.js";

export async function scanRepoLive(
  repoPath: string,
  settings: AppSettings
): Promise<{ commitDays: CommitDay[]; lastCommitDate: Date | null }> {
  // Validate path
  if (!fs.existsSync(repoPath)) {
    throw new Error(`Path '${repoPath}' does not exist.`);
  }
  const gitDir = path.join(repoPath, ".git");
  if (!fs.existsSync(gitDir)) {
    throw new Error(
      `Path '${repoPath}' is not a git repository (no .git directory).`
    );
  }

  const sinceDate = new Date();
  sinceDate.setDate(sinceDate.getDate() - settings.dayRange);
  const sinceStr = sinceDate.toISOString().split("T")[0];

  const args = [
    "-C",
    repoPath,
    "log",
    "--format=%at",
    "--all",
    `--since=${sinceStr}`,
  ];

  for (const email of settings.authorEmails) {
    const trimmed = email.trim();
    if (trimmed && !trimmed.includes("\0") && !trimmed.includes("\n")) {
      args.push(`--author=${trimmed}`);
    }
  }

  const output = await runGit(args);
  const timestamps = output
    .split("\n")
    .filter((line) => line.trim())
    .map(Number)
    .filter((ts) => !isNaN(ts));

  const commitDays = aggregateCommits(timestamps, settings.dayRange);
  const maxTs = timestamps.length > 0 ? Math.max(...timestamps) : null;
  const lastCommitDate = maxTs !== null ? new Date(maxTs * 1000) : null;

  return { commitDays, lastCommitDate };
}

function aggregateCommits(timestamps: number[], dayRange: number): CommitDay[] {
  const now = new Date();
  now.setHours(0, 0, 0, 0);

  const dayCounts = new Map<string, number>();
  for (let i = 0; i < dayRange; i++) {
    const day = new Date(now);
    day.setDate(day.getDate() - i);
    dayCounts.set(day.toISOString().split("T")[0], 0);
  }

  for (const ts of timestamps) {
    const date = new Date(ts * 1000);
    date.setHours(0, 0, 0, 0);
    const key = date.toISOString().split("T")[0];
    const current = dayCounts.get(key);
    if (current !== undefined) {
      dayCounts.set(key, current + 1);
    }
  }

  return Array.from(dayCounts.entries())
    .map(([dateStr, count]) => ({
      date: new Date(dateStr).getTime() / 1000, // epoch seconds to match Swift format
      count,
    }))
    .sort((a, b) => (a.date as number) - (b.date as number));
}

function runGit(args: string[]): Promise<string> {
  return new Promise((resolve, reject) => {
    execFile(
      "/usr/bin/git",
      args,
      {
        env: {
          HOME: os.homedir(),
          PATH: "/usr/bin:/bin",
          GIT_TERMINAL_PROMPT: "0",
          GIT_CONFIG_NOSYSTEM: "1",
          GIT_CONFIG_GLOBAL: "/dev/null",
        },
        maxBuffer: 10 * 1024 * 1024,
      },
      (error, stdout, stderr) => {
        if (error) {
          reject(
            new Error(
              `Git command failed: ${stderr?.trim() || error.message}`
            )
          );
        } else {
          resolve(stdout);
        }
      }
    );
  });
}
