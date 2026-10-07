const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const assert = require('node:assert/strict');
const {spawnSync, spawn} = require('node:child_process');
const {createHash} = require('node:crypto');
const abi = 'efb50993780079460b0cbed1363e2166a2de1d9f_aq_0.15_hu_0.14_hg_0.5_hc_0.1_hlg_0.6';
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'familiar-ui-setup-'));
const home = path.join(tmp,'home'), root = path.join(home,'.config/omarchy/plugins/io.github.tcballard.familiar-desktop');
const mock = path.join(tmp,'mock'), log = path.join(tmp,'calls');
fs.mkdirSync(path.join(root,'.git'), {recursive:true}); fs.mkdirSync(mock);
fs.copyFileSync('setup-in-app.sh',path.join(root,'setup-in-app.sh'));
fs.copyFileSync('bar-placement.sh',path.join(root,'bar-placement.sh'));
function write(p, s) { fs.mkdirSync(path.dirname(p),{recursive:true}); fs.writeFileSync(p,s,{mode:0o755}); }
const helper = `#!/bin/bash
set -e
printf '%s\\n' "$*" >> "$CALLS"
[[ "$*" != "$FAIL" ]] || { echo 'fixture failure' >&2; exit 1; }
if [[ "$*" == titlebars\\ setup* ]]; then
 mkdir -p "$HOME/.config/omarchy/familiar-titlebars" "$HOME/.config/hypr"
 jq -n --arg source "$ROOT" --arg library "$ROOT/bin/hyprbars/$ABI/hyprbars.so" '{source:$source,library:$library,hookVersion:2}' > "$HOME/.config/omarchy/familiar-titlebars/owner.json"
 echo '-- BEGIN Familiar Desktop title bars' > "$HOME/.config/hypr/looknfeel.lua"
 echo '{"state":"ready"}'
elif [[ "$*" == titlebars\\ apply* ]]; then echo '{"state":"active"}'; fi
`;
const library='fixture library';
const sha=s=>createHash('sha256').update(s).digest('hex');
write(path.join(root,'release-binaries.sha256'),`${sha(helper)}  familiar-desktop-linux-x86_64\n${sha(library)}  hyprbars-linux-x86_64-${abi}.so\n`);
write(path.join(tmp,'helper'),helper); write(path.join(tmp,'library'),library);
write(path.join(root,'install-backend.sh'),`#!/bin/bash\necho download-backend >> "$CALLS"\n[[ "$STALL" != 1 ]] || sleep 30\n[[ "$FAIL" != download ]] || exit 1\nmkdir -p "$ROOT/bin"\ncp "$FIXTURE/helper" "$ROOT/bin/familiar-desktop"\n[[ "$CORRUPT" != 1 ]] || echo corrupt >> "$ROOT/bin/familiar-desktop"\n`);
write(path.join(root,'install-titlebars.sh'),`#!/bin/bash\n[[ "$FAIL" != abi ]] || exit 1\n[[ "$1" != --check ]] || exit 0\necho download-titlebars >> "$CALLS"\nmkdir -p "$ROOT/bin/hyprbars/$ABI"\ncp "$FIXTURE/library" "$ROOT/bin/hyprbars/$ABI/hyprbars.so"\n`);
write(path.join(mock,'git'),'#!/bin/bash\n[[ "$DIRTY" != 1 ]] || echo " M file"\n');
for (const n of ['omarchy-shell','sudo','pkexec','foot','kitty']) write(path.join(mock,n),'#!/bin/bash\necho forbidden >> "$CALLS"\nexit 99\n');
write(path.join(mock,'omarchy'),'#!/bin/bash\n[[ "$1 $2 $3" == "bar move io.github.tcballard.familiar-desktop" ]] || { echo forbidden >> "$CALLS"; exit 99; }\necho "omarchy $*" >> "$CALLS"\n');
const env={...process.env,HOME:home,XDG_STATE_HOME:path.join(home,'.local/state'),XDG_CONFIG_HOME:path.join(home,'.config'),PATH:mock+':'+process.env.PATH,ROOT:root,FIXTURE:tmp,ABI:abi,CALLS:log};
write(path.join(mock,'hyprctl'),'#!/bin/bash\nexit 0\n');
function run(mode, extra={}) { return spawnSync('bash',[path.join(root,'setup-in-app.sh'),mode,'mac'],{env:{...env,...extra},encoding:'utf8'}); }
(async () => {
try {
 assert.equal(run('status').status,3);
 let r=run('install'); assert.equal(r.status,0,r.stdout+r.stderr); assert.equal(run('status').status,0);
 let calls=fs.readFileSync(log,'utf8'); assert.match(calls,/titlebars setup .*--style mac/); assert.doesNotMatch(calls,/forbidden/);
 // Existing reviewed backend is recovered before replacement.
 r=run('install'); assert.equal(r.status,0,r.stdout+r.stderr); calls=fs.readFileSync(log,'utf8'); assert.match(calls,/desktop restore\ntitlebars disable\ndownload-backend/);
 // Failed/interrupted setup remains incomplete even when old assets exist.
 for(const failure of ['abi','download','titlebars apply --style mac --mode mac']) {
   r=run('install',{FAIL:failure}); assert.notEqual(r.status,0); assert.equal(run('status').status,3);
   assert.equal(run('install').status,0);
 }
 fs.writeFileSync(log,''); r=run('install',{CORRUPT:'1'}); assert.notEqual(r.status,0); assert.doesNotMatch(fs.readFileSync(log,'utf8'),/titlebars setup/); assert.equal(run('status').status,3);
 // A tampered existing binary is never executed, and successful retry replaces it.
 fs.writeFileSync(log,''); assert.equal(run('install').status,0); assert.doesNotMatch(fs.readFileSync(log,'utf8'),/desktop restore/);
 fs.writeFileSync(log,''); assert.notEqual(run('install',{DIRTY:'1'}).status,0); assert.equal(fs.readFileSync(log,'utf8'),'');
 fs.writeFileSync(path.join(home,'.local/state/familiar-desktop/setup-pending'),'interrupted'); assert.equal(run('status').status,3);
 // Real flock exclusion prevents duplicate setup, including after shell reload.
 const lock=spawnSync('flock',[path.join(home,'.local/state/familiar-desktop/setup.lock'),'bash',path.join(root,'setup-in-app.sh'),'install'],{env,encoding:'utf8'});
 assert.equal(lock.status,4,lock.stdout+lock.stderr);
 // TERM delivered through the same timeout supervisor used by QML must leave no active partial setup.
 fs.writeFileSync(log,'');
 const cancelled = await new Promise((resolve, reject) => {
   const child = spawn('timeout',['--kill-after=2','10','bash',path.join(root,'setup-in-app.sh'),'install','mac'],{env:{...env,STALL:'1'},stdio:'ignore'});
   const stop = setTimeout(() => child.kill('SIGTERM'), 200);
   child.on('error', reject);
   child.on('exit', code => { clearTimeout(stop); resolve(code); });
 });
 assert.notEqual(cancelled,0);
 let stopped = run('status').status;
 for(let i=0; stopped===4 && i<30; i++) { await new Promise(resolve=>setTimeout(resolve,100)); stopped=run('status').status; }
 assert.equal(stopped,3);
 assert.doesNotMatch(fs.readFileSync(log,'utf8'),/titlebars apply/);
 assert.equal(run('install').status,0);
 console.log('In-app setup: fresh install, existing install, failure/retry, interrupted state, source refusal, corrupt bytes, and concurrency passed.');
} finally { fs.rmSync(tmp,{recursive:true,force:true}); }

})().catch(error => { console.error(error); process.exitCode = 1; });
