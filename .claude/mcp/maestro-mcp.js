#!/usr/bin/env node
// Launches `maestro mcp` (Maestro's built-in MCP server) over stdio on every
// OS. On Windows the CLI is `maestro.bat`, which cannot be spawned without a
// shell, so .mcp.json points here instead of at `maestro` directly.
'use strict';

const { spawn } = require('child_process');

const child = spawn('maestro', ['mcp', ...process.argv.slice(2)], {
  stdio: 'inherit',
  shell: process.platform === 'win32',
});

child.on('error', (err) => {
  process.stderr.write(
    `maestro-mcp: could not start "maestro mcp" (${err.message}). `
    + 'Install the Maestro CLI: https://docs.maestro.dev/getting-started/installing-maestro\n',
  );
  process.exit(1);
});
child.on('exit', (code) => process.exit(code ?? 1));
