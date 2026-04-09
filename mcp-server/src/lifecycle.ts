import { execFile } from "node:child_process";
import { McpError, ErrorCode } from "@modelcontextprotocol/sdk/types.js";

export async function assertAppRunning(): Promise<void> {
  return new Promise((resolve, reject) => {
    execFile("pgrep", ["-x", "ProjectPulse"], (error) => {
      if (error) {
        reject(
          new McpError(
            ErrorCode.InternalError,
            "ProjectPulse is not running. Launch the app first to use these tools."
          )
        );
      } else {
        resolve();
      }
    });
  });
}

export async function isAppRunning(): Promise<boolean> {
  return new Promise((resolve) => {
    execFile("pgrep", ["-x", "ProjectPulse"], (error) => {
      resolve(!error);
    });
  });
}
