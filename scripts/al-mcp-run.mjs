// Headless AL MCP client. Spawns `altool launchmcpserver --transport stdio`,
// performs the MCP handshake, then runs a sequence of tool calls given on argv.
//
// Usage:
//   node al-mcp-run.mjs <altoolPath> <projectPath> <callsJsonFile>
//
// callsJsonFile is a JSON array of { name, arguments } tool calls run in order.
// Prints each result as JSON. Exits non-zero if any call reports an error or a
// failed compile.

import { spawn } from 'node:child_process';
import { readFileSync } from 'node:fs';

const [altoolPath, projectPath, callsFile] = process.argv.slice(2);
if (!altoolPath || !projectPath || !callsFile) {
  console.error('args: <altoolPath> <projectPath> <callsJsonFile>');
  process.exit(2);
}
const calls = JSON.parse(readFileSync(callsFile, 'utf8'));

const child = spawn(altoolPath, ['launchmcpserver', projectPath, '--transport', 'stdio'], {
  stdio: ['pipe', 'pipe', 'pipe'],
});

let buf = '';
const pending = new Map();
let nextId = 1;

child.stdout.on('data', (d) => {
  buf += d.toString();
  let idx;
  while ((idx = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, idx).trim();
    buf = buf.slice(idx + 1);
    if (!line) continue;
    let msg;
    try { msg = JSON.parse(line); } catch { continue; }
    if (msg.id != null && pending.has(msg.id)) {
      const { resolve } = pending.get(msg.id);
      pending.delete(msg.id);
      resolve(msg);
    }
  }
});
child.stderr.on('data', (d) => process.stderr.write(`[server] ${d}`));
child.on('exit', (code) => { if (code) console.error(`server exited ${code}`); });

function rpc(method, params) {
  const id = nextId++;
  const req = { jsonrpc: '2.0', id, method, params };
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    child.stdin.write(JSON.stringify(req) + '\n');
    setTimeout(() => {
      if (pending.has(id)) { pending.delete(id); reject(new Error(`timeout on ${method}`)); }
    }, 600000);
  });
}
function notify(method, params) {
  child.stdin.write(JSON.stringify({ jsonrpc: '2.0', method, params }) + '\n');
}

async function main() {
  const init = await rpc('initialize', {
    protocolVersion: '2024-11-05',
    capabilities: {},
    clientInfo: { name: 'al-mcp-run', version: '0.1.0' },
  });
  console.error('[init] ' + JSON.stringify(init.result?.serverInfo ?? {}));
  notify('notifications/initialized', {});

  let failed = false;
  for (const call of calls) {
    console.error(`\n=== tools/call ${call.name} ===`);
    const res = await rpc('tools/call', { name: call.name, arguments: call.arguments ?? {} });
    if (res.error) {
      console.log(JSON.stringify({ call: call.name, error: res.error }, null, 2));
      failed = true;
      continue;
    }
    const content = res.result?.content ?? [];
    for (const c of content) {
      if (c.type === 'text') {
        console.log(`--- ${call.name} text ---`);
        console.log(c.text);
        try {
          const parsed = JSON.parse(c.text);
          if (parsed.Succeeded === false) failed = true;
        } catch { /* not json, ignore */ }
      } else {
        console.log(JSON.stringify(c));
      }
    }
    if (res.result?.isError) failed = true;
  }

  child.stdin.end();
  setTimeout(() => child.kill(), 1000);
  process.exit(failed ? 1 : 0);
}

main().catch((e) => { console.error(e); child.kill(); process.exit(1); });
