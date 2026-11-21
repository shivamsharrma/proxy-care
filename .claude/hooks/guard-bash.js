#!/usr/bin/env node
// PreToolUse hook for Bash and PowerShell: blocks destructive or
// secret-exposing commands. See .claude/rules/security.md and git-and-pr.md.
'use strict';

const { execFileSync } = require('child_process');
const { isSecretPath, readInput, block } = require('./lib');

const PROTECTED_BRANCHES = ['main', 'master'];

// Each rule: [regex over the normalized command, reason].
const RULES = [
  [/\bgit\s+push\b[^|;&]*\s(--force(-with-lease)?|-f\b|--mirror|--delete|-d\b)/i,
    'Force/mirror/delete pushes are blocked. Push a normal branch and open a PR.'],
  [/\bgit\s+push\b[^|;&]*\s\+\S+/i,
    'Force pushes via +refspec are blocked.'],
  [new RegExp(`\\bgit\\s+push\\b[^|;&]*[\\s:](${PROTECTED_BRANCHES.join('|')})\\b(?!-)`, 'i'),
    'Pushing to main is blocked. Push a feature branch and open a PR (/open-pr).'],
  [/\bgit\s+(commit|push|merge|rebase)\b[^|;&]*--no-verify\b/i,
    '--no-verify is blocked; fix the failing hook instead.'],
  [/\bgh\s+pr\s+merge\b/i,
    'Merging PRs is a human decision; Claude never merges.'],
  [/\brm\s+(-[a-z]*r[a-z]*f[a-z]*|-[a-z]*f[a-z]*r[a-z]*|(-[a-z]*r[a-z]*\s+-[a-z]*f[a-z]*)|(-[a-z]*f[a-z]*\s+-[a-z]*r[a-z]*)|--recursive\s+--force|--force\s+--recursive)\b/i,
    'rm -rf is blocked. Use `flutter clean` / `./gradlew clean`, or ask the user to delete.'],
  [/\bRemove-Item\b(?=[^|;]*-Recurse)(?=[^|;]*-Force)/i,
    'Remove-Item -Recurse -Force is blocked. Ask the user to delete.'],
  [/\b(rd|rmdir)\s+\/s\b/i,
    'rmdir /s is blocked. Ask the user to delete.'],
  [/\bgit\s+(reset\s+--hard|clean\s+-[a-z]*f)/i,
    'git reset --hard / git clean -f discard work and are blocked. Ask the user.'],
  [/\baws\s+secretsmanager\s+get-secret-value\b|\baws\s+ssm\s+get-parameters?\b[^|;&]*--with-decryption/i,
    'Reading secret values is blocked.'],
  [/\bsupabase\s+(secrets\s+list|db\s+push|db\s+reset\s+--linked)/i,
    'Supabase secret listing and pushes to remote databases are blocked; migrations ship through CI.'],
  [/^\s*(printenv|env|Get-ChildItem\s+env:|gci\s+env:|dir\s+env:|set)\s*$/im,
    'Dumping the whole environment can expose secrets. Read a specific non-secret variable instead.'],
];

function currentBranch(cwd) {
  try {
    return execFileSync('git', ['rev-parse', '--abbrev-ref', 'HEAD'], {
      cwd: cwd || process.cwd(), encoding: 'utf8', timeout: 2000,
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch {
    return '';
  }
}

(async () => {
  const input = await readInput();
  const command = String((input.tool_input && input.tool_input.command) || '');
  if (!command) process.exit(0);

  for (const [re, reason] of RULES) {
    if (re.test(command)) block(`${reason}\nCommand: ${command}`);
  }

  // A bare `git push` (no refspec) pushes the current branch.
  if (/\bgit\s+push\b/i.test(command)
      && PROTECTED_BRANCHES.includes(currentBranch(input.cwd))) {
    block('You are on main; pushing is blocked. Create a feature branch first.');
  }

  if (isSecretPath(command)) {
    block('The command references a secret file (.env, key, keystore, credentials). '
      + 'Never read or print secrets; ask the user for the non-secret value you need.');
  }

  process.exit(0);
})();
