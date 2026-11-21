// Shared helpers for the Proxy Care Claude Code hooks. Node 18+, no
// dependencies, works on Windows, macOS and Linux.
'use strict';

// Files that hold credentials. Matched against a path or a shell command.
// `.env.example` / `.env.sample` / `.env.template` are allowed.
const SECRET_PATH_PATTERNS = [
  /(^|[\s/\\'"=:])\.env(?!\.(example|sample|template)\b)(\.[\w-]+)?(?=$|[\s'";|&)>])/i,
  /\.(pem|p12|pfx|jks|keystore|key)(?=$|[\s'";|&)>])/i,
  /(^|[\s/\\'"])key\.properties\b/i,
  /(^|[\s/\\'"])(google-services\.json|GoogleService-Info\.plist)\b/i,
  /(^|[\s/\\'"])id_(rsa|ed25519|ecdsa)\b/i,
  /\.aws[/\\](credentials|config)\b/i,
  /(^|[\s/\\'"])secrets?[/\\]/i,
  /(^|[\s/\\'"])application-(prod|production|staging)\.ya?ml\b/i,
];

function isSecretPath(text) {
  return SECRET_PATH_PATTERNS.some((re) => re.test(text));
}

// Reads the hook's JSON payload from stdin. Resolves to {} on bad input so a
// malformed payload never wedges the session.
function readInput() {
  return new Promise((resolve) => {
    let data = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (chunk) => (data += chunk));
    process.stdin.on('end', () => {
      try {
        resolve(JSON.parse(data || '{}'));
      } catch {
        resolve({});
      }
    });
  });
}

// Exit code 2 blocks the tool call (PreToolUse) or the stop (Stop hooks);
// stderr is shown to Claude as the reason.
function block(reason) {
  process.stderr.write(`[proxy-care hook] ${reason}\n`);
  process.exit(2);
}

module.exports = { isSecretPath, readInput, block };
