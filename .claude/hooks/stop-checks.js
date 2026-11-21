#!/usr/bin/env node
// Stop / SubagentStop hook: fast static checks (< 5 s) on lines added since
// HEAD plus untracked files. Blocks the stop with a list of problems so
// Claude fixes them before handing back. No builds, no analyzers.
'use strict';

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { readInput, block } = require('./lib');

const BUDGET_MS = 4000;
const MAX_FILE_BYTES = 512 * 1024;
const started = Date.now();

// [regex over one added line, message, optional path filter].
const CHECKS = [
  [/^(<{7}|>{7})( |$)/, 'merge conflict marker'],
  [/-----BEGIN [A-Z ]*PRIVATE KEY-----/, 'private key'],
  [/\bAKIA[0-9A-Z]{16}\b/, 'AWS access key id'],
  [/\brzp_live_[A-Za-z0-9]{8,}/, 'Razorpay live key'],
  [/\bsb_secret_[A-Za-z0-9_-]{10,}/, 'Supabase secret key'],
  [/\b(ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{40,})\b/, 'GitHub token'],
  [/service_role/i, 'Supabase service_role reference in client code',
    (f) => /^proxy-care-client\/(lib|config)\//.test(f)],
  [/package:shared_preferences\//, 'shared_preferences import (tokens must use SecureKeyValueStore)',
    (f) => f.startsWith('proxy-care-client/lib/')],
  [/\b(skip:\s*true|skip:\s*'[^']*'|@Disabled\b|\.only\()/, 'skipped/focused test',
    (f) => /(^|\/)(test|src\/test|maestro)\//.test(f)],
  [/--update-goldens/, 'golden update outside CI',
    (f) => !f.endsWith('.md') && !f.startsWith('.github/') && !f.endsWith('Makefile')],
];

const GENERATED = /\.(g|freezed)\.dart$|\/l10n\/generated\//;
const SELF = /^\.claude\/hooks\//;

function git(args, cwd) {
  return execFileSync('git', args, {
    cwd, encoding: 'utf8', timeout: 2500, maxBuffer: 32 * 1024 * 1024,
    stdio: ['ignore', 'pipe', 'ignore'],
  });
}

// Returns Map<file, Array<{line, text}>> of added lines.
function addedLines(cwd) {
  const out = new Map();
  let file = null;
  let lineNo = 0;
  for (const raw of git(['diff', 'HEAD', '-U0', '--no-color', '--no-ext-diff'], cwd).split('\n')) {
    if (raw.startsWith('+++ ')) {
      file = raw.startsWith('+++ b/') ? raw.slice(6) : null;
    } else if (raw.startsWith('@@')) {
      const m = /\+(\d+)/.exec(raw);
      lineNo = m ? Number(m[1]) : 0;
    } else if (file && raw.startsWith('+')) {
      if (!out.has(file)) out.set(file, []);
      out.get(file).push({ line: lineNo++, text: raw.slice(1) });
    }
  }
  for (const f of git(['ls-files', '--others', '--exclude-standard'], cwd).split('\n')) {
    if (!f || Date.now() - started > BUDGET_MS) continue;
    const abs = path.join(cwd, f);
    try {
      if (fs.statSync(abs).size > MAX_FILE_BYTES) continue;
      const text = fs.readFileSync(abs, 'utf8');
      if (text.includes('\u0000')) continue; // binary
      out.set(f, text.split(/\r?\n/).map((t, i) => ({ line: i + 1, text: t })));
    } catch { /* unreadable: skip */ }
  }
  return out;
}

(async () => {
  const input = await readInput();
  // Already blocked once this turn: let Claude stop to avoid a loop.
  if (input.stop_hook_active) process.exit(0);

  let cwd;
  try {
    cwd = git(['rev-parse', '--show-toplevel'], input.cwd || process.cwd()).trim();
  } catch {
    process.exit(0); // not a git repo
  }

  let files;
  try {
    files = addedLines(cwd);
  } catch {
    process.exit(0); // git timed out or failed: never block on infra problems
  }

  const problems = [];
  for (const [file, lines] of files) {
    if (Date.now() - started > BUDGET_MS) break;
    if (SELF.test(file) || GENERATED.test(file)) continue;
    for (const { line, text } of lines) {
      for (const [re, msg, applies] of CHECKS) {
        if ((!applies || applies(file)) && re.test(text)) {
          problems.push(`${file}:${line} — ${msg}`);
        }
      }
    }
    if (file.endsWith('.json') && (file.startsWith('.claude') || file === '.mcp.json')) {
      try {
        JSON.parse(fs.readFileSync(path.join(cwd, file), 'utf8'));
      } catch (e) {
        problems.push(`${file} — invalid JSON (${e.message})`);
      }
    }
  }

  if (problems.length) {
    block('Fast checks found problems in your changes:\n  '
      + problems.slice(0, 25).join('\n  ')
      + (problems.length > 25 ? `\n  …and ${problems.length - 25} more` : '')
      + '\nFix them (or explain to the user why one is a false positive) before finishing.');
  }
  process.exit(0);
})();
