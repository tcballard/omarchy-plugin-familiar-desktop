const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const installer = path.resolve(__dirname, '../install.sh');
let passed = 0;
function run({existing=false, dirty=false, repair=false, failRepair=false, missing=false, style='mac'}={}) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'familiar-install-'));
  try {
    const bin = path.join(root, 'bin'); fs.mkdirSync(bin);
    const plugin = path.join(root, '.config/omarchy/plugins/io.github.tcballard.familiar-desktop');
    const fixture = path.join(root, 'fixture');
    fs.mkdirSync(path.join(fixture, '.git'), {recursive:true});
    fs.mkdirSync(path.join(fixture, 'bin'));
    fs.writeFileSync(path.join(fixture,'manifest.json'), '{}');
    fs.writeFileSync(path.join(fixture,'build.sh'), 'echo build >> "$LOG"\n');
    fs.writeFileSync(path.join(fixture,'bin/familiar-desktop'), `#!/bin/bash\necho "helper $*" >> "$LOG"\nif [[ "$*" == *setup* ]]; then\n if [[ "$*" == *--install-dependency* ]]; then exit "$FAIL_REPAIR"; fi\n exit "$REPAIR"\nfi\necho familiar-desktop 0.0.2\n`, {mode:0o755});
    if(existing) fs.cpSync(fixture,plugin,{recursive:true});
    const mock = `#!/bin/bash\nname="$(basename "$0")"\necho "$name $*" >> "$LOG"\ncase "$name" in\nomarchy) if [[ "$*" == plugin\\ add* ]]; then mkdir -p "$(dirname "$PLUGIN")"; cp -r "$FIXTURE" "$PLUGIN"; fi;;\ngit) if [[ "$*" == *status* && "$DIRTY" == 1 ]]; then echo ' M README.md'; fi;;\nhyprctl) [[ "$MISSING" != 1 ]] || exit 1;;\nesac\n`;
    for(const name of ['omarchy','omarchy-shell','hyprctl','hyprpm','cargo','rustup','git','make','cc','sudo']) fs.writeFileSync(path.join(bin,name), mock,{mode:0o755});
    const log=path.join(root,'calls');
    const p=spawnSync('/bin/bash',[installer,style],{encoding:'utf8',env:{...process.env,HOME:root,PATH:bin+':/usr/bin:/bin',LOG:log,PLUGIN:plugin,FIXTURE:fixture,DIRTY:+dirty+'',REPAIR:+repair+'',FAIL_REPAIR:+failRepair+'',MISSING:+missing+''}});
    return {...p,log:fs.existsSync(log)?fs.readFileSync(log,'utf8'):''};
  } finally {fs.rmSync(root,{recursive:true,force:true});}
}
for(const existing of [false,true]) {
 const r=run({existing}); assert.equal(r.status,0,r.stderr);
 assert.equal(r.log.includes('omarchy plugin add'),!existing);
 assert.match(r.log,/checkout --detach v0\.0\.2/);
 assert.doesNotMatch(r.log,/--install-dependency/);
 assert.ok(r.log.indexOf('build\n') < r.log.indexOf('omarchy plugin enable'));
 passed++;
}
let r=run({repair:true,style:'windows'}); assert.equal(r.status,0,r.stderr); assert.match(r.log,/setup --install-dependency --enable --style windows/); assert.match(r.stdout,/does not replace/); passed++;
r=run({existing:true,dirty:true}); assert.notEqual(r.status,0); assert.doesNotMatch(r.log,/checkout|helper|plugin enable/); passed++;
r=run({repair:true,failRepair:true}); assert.notEqual(r.status,0); assert.doesNotMatch(r.log,/plugin enable/); passed++;
r=run({missing:true}); assert.notEqual(r.status,0); assert.doesNotMatch(r.log,/plugin add|checkout/); passed++;
r=run({style:'bogus'}); assert.notEqual(r.status,0); assert.equal(r.log,''); passed++;
console.log(`${passed} installer scenarios passed (mock tools; no live desktop).`);
