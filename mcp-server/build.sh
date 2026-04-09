#!/bin/bash
set -e

cd "$(dirname "$0")"

if [ ! -d node_modules ]; then
  echo "Installing dependencies..."
  npm install
fi

echo "Building MCP server..."
npm run build

chmod +x dist/index.js

echo ""
echo "Build complete! Add to Claude Code settings.json:"
echo ""
echo '  "mcpServers": {'
echo '    "project-pulse": {'
echo '      "command": "node",'
echo "      \"args\": [\"$(pwd)/dist/index.js\"]"
echo '    }'
echo '  }'
