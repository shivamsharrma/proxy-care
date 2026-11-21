#!/usr/bin/env node
// PreToolUse hook for file tools (Read, Edit, Write, Grep, Glob, ...): blocks
// access to credential files. See .claude/rules/security.md.
'use strict';

const { isSecretPath, readInput, block } = require('./lib');

(async () => {
  const input = await readInput();
  const ti = input.tool_input || {};
  // Glob's `pattern` is a path glob; Grep's `pattern` is a regex over file
  // contents, so it is not a path and is not checked.
  const globPattern = input.tool_name === 'Glob' ? ti.pattern : undefined;
  const targets = [ti.file_path, ti.notebook_path, ti.path, ti.glob, globPattern]
    .filter((v) => typeof v === 'string' && v.length > 0);

  for (const target of targets) {
    if (isSecretPath(target)) {
      block(`Access to secret file "${target}" is blocked. `
        + 'Ask the user for the non-secret value you need.');
    }
  }
  process.exit(0);
})();
