import { describe, it, expect, vi } from "vitest";
import { execFile } from "node:child_process";
import { assertAppRunning, isAppRunning } from "../lifecycle.js";

vi.mock("node:child_process");

describe("assertAppRunning", () => {
  it("resolves when pgrep finds the process", async () => {
    vi.mocked(execFile).mockImplementation(
      ((_cmd: unknown, _args: unknown, cb: unknown) => {
        (cb as (err: Error | null) => void)(null);
      }) as typeof execFile
    );
    await expect(assertAppRunning()).resolves.toBeUndefined();
  });

  it("rejects with McpError when process not found", async () => {
    vi.mocked(execFile).mockImplementation(
      ((_cmd: unknown, _args: unknown, cb: unknown) => {
        (cb as (err: Error | null) => void)(new Error("exit code 1"));
      }) as typeof execFile
    );
    await expect(assertAppRunning()).rejects.toThrow("ProjectPulse is not running");
  });
});

describe("isAppRunning", () => {
  it("returns true when process found", async () => {
    vi.mocked(execFile).mockImplementation(
      ((_cmd: unknown, _args: unknown, cb: unknown) => {
        (cb as (err: Error | null) => void)(null);
      }) as typeof execFile
    );
    expect(await isAppRunning()).toBe(true);
  });

  it("returns false when process not found", async () => {
    vi.mocked(execFile).mockImplementation(
      ((_cmd: unknown, _args: unknown, cb: unknown) => {
        (cb as (err: Error | null) => void)(new Error("exit code 1"));
      }) as typeof execFile
    );
    expect(await isAppRunning()).toBe(false);
  });
});
