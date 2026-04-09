#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { registerRepoTools } from "./tools/repos.js";
import { registerActivityTools } from "./tools/activity.js";
import { registerDomainTools } from "./tools/domains.js";
import { registerAnalysisTools } from "./tools/analysis.js";
import { registerSystemTools } from "./tools/system.js";

async function main() {
  const server = new McpServer({
    name: "project-pulse",
    version: "1.0.0",
  });

  registerRepoTools(server);
  registerActivityTools(server);
  registerDomainTools(server);
  registerAnalysisTools(server);
  registerSystemTools(server);

  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((err) => {
  process.stderr.write(`MCP server error: ${err}\n`);
  process.exit(1);
});
