const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const {spawnSync} = require('node:child_process');
const installer = path.resolve(__dirname, '../install.sh');
let passed = 0;
function run({existing=false, dirty=false, repair=false, failRepair=false, missing=false, style='mac', fault='', arch='x86_64', noCompiler=false}={}) {
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'familiar-install-'));
 try {
  const bin=path.join(root,'bin');fs.mkdirSync(bin);
  const plugin=path.join(root,'.config/omarchy/plugins/io.github.tcballard.familiar-desktop');
  const fixture=path.join(root,'fixture');fs.mkdirSync(path.join(fixture,'.git'),{recursive:true});fs.mkdirSync(path.join(fixture,'bin'));
  fs.writeFileSync(path.join(fixture,'manifest.json'),'{}');
  fs.copyFileSync(path.resolve(__dirname,'../install-backend.sh'),path.join(fixture,'install-backend.sh'));
  fs.writeFileSync(path.join(fixture,'build.sh'),'echo forbidden-build >> "$LOG"; exit 99\n');
  const old='previous backend';fs.writeFileSync(path.join(fixture,'bin/familiar-desktop'),old);
  const asset=path.join(root,'asset');
  fs.writeFileSync(asset,`#!/bin/bash\necho "helper $*" >> "$LOG"\nif [[ "$*" == *setup* ]]; then\n if [[ "$*" == *--install-dependency* ]]; then exit "$FAIL_REPAIR"; fi\n exit "$REPAIR"\nfi\necho familiar-desktop ${fault==='version'?'0.0.2':'0.0.3'}\n`);
  const hash=crypto.createHash('sha256').update(fs.readFileSync(asset)).digest('hex');
  fs.writeFileSync(path.join(root,'sums'),`${fault==='corrupt'?'0'.repeat(64):hash}  familiar-desktop-linux-x86_64\n`+(fault==='duplicate'?`${hash}  familiar-desktop-linux-x86_64\n`:''));
  if(existing)fs.cpSync(fixture,plugin,{recursive:true});
  const mock=`#!/bin/bash\nname="$(basename "$0")"\necho "$name $*" >> "$LOG"\ncase "$name" in\nomarchy) if [[ "$*" == plugin\\ add* ]]; then mkdir -p "$(dirname "$PLUGIN")"; cp -r "$FIXTURE" "$PLUGIN"; fi;;\ngit) if [[ "$*" == *status* && "$DIRTY" == 1 ]]; then echo ' M README.md'; fi;;\nhyprctl) [[ "$MISSING" != 1 ]] || exit 1;;\nuname) if [[ "$*" == -m ]]; then echo "$ARCH"; else echo Linux; fi;;\ncurl) [[ "$FAULT" != download ]] || exit 22; if [[ "$*" == *SHA256SUMS* ]]; then cp "$SUMS" "\${@: -1}"; else cp "$ASSET" "\${@: -1}"; fi;;\ncargo|rustup|clippy|make|cc) exit 99;;\nesac\n`;
  for(const name of ['omarchy','omarchy-shell','hyprctl','hyprpm','cargo','rustup','clippy','git','sudo','curl','uname',...(!noCompiler?['make','cc']:[])])fs.writeFileSync(path.join(bin,name),mock,{mode:0o755});
  const log=path.join(root,'calls');
  const p=spawnSync('/bin/bash',[installer,style],{encoding:'utf8',env:{...process.env,HOME:root,PATH:bin+':/usr/bin:/bin',LOG:log,PLUGIN:plugin,FIXTURE:fixture,ASSET:asset,SUMS:path.join(root,'sums'),FAULT:fault,ARCH:arch,DIRTY:+dirty+'',REPAIR:+repair+'',FAIL_REPAIR:+failRepair+'',MISSING:+missing+''}});
  const binary=path.join(plugin,'bin/familiar-desktop');
  return {...p,log:fs.existsSync(log)?fs.readFileSync(log,'utf8'):'',binary:fs.existsSync(binary)?fs.readFileSync(binary,'utf8'):null,staging:fs.existsSync(path.dirname(binary))?fs.readdirSync(path.dirname(binary)).filter(n=>n.startsWith('.download')):[]};
 }finally{fs.rmSync(root,{recursive:true,force:true});}
}
for(const existing of [false,true]){
 const r=run({existing});assert.equal(r.status,0,r.stderr);assert.equal(r.log.includes('omarchy plugin add'),!existing);assert.match(r.log,/checkout --detach v0\.0\.3/);assert.doesNotMatch(r.log,/--install-dependency|cargo|rustup|clippy|forbidden-build|sudo/);assert.ok(r.log.indexOf('helper --version')<r.log.indexOf('omarchy plugin enable'));assert.deepEqual(r.staging,[]);passed++;
}
let r=run({repair:true,style:'windows'});assert.equal(r.status,0,r.stderr);assert.match(r.log,/setup --install-dependency --enable --style windows/);passed++;
r=run({existing:true,dirty:true});assert.notEqual(r.status,0);assert.doesNotMatch(r.log,/checkout|helper|plugin enable/);passed++;
r=run({repair:true,failRepair:true});assert.notEqual(r.status,0);assert.doesNotMatch(r.log,/plugin enable/);passed++;
r=run({missing:true});assert.notEqual(r.status,0);assert.doesNotMatch(r.log,/plugin add|checkout/);passed++;
r=run({style:'bogus'});assert.notEqual(r.status,0);assert.equal(r.log,'');passed++;
for(const fault of ['download','corrupt','duplicate','version']){
 r=run({existing:true,fault});assert.notEqual(r.status,0);assert.equal(r.binary,'previous backend');assert.doesNotMatch(r.log,/setup|plugin enable|cargo|rustup|clippy|forbidden-build/);assert.deepEqual(r.staging,[]);if(fault==='corrupt')assert.doesNotMatch(r.log,/helper/);passed++;
}
r=run({existing:true,arch:'aarch64'});assert.notEqual(r.status,0);assert.equal(r.binary,'previous backend');assert.match(r.stderr,/Supported: Linux x86_64/);assert.doesNotMatch(r.log,/curl|plugin enable/);passed++;
// The settings repair action must use the release installer, never a source build.
const widget=fs.readFileSync(path.resolve(__dirname,'../BarWidget.qml'),'utf8');assert.match(widget,/Qt.resolvedUrl\("install.sh"\)/);assert.doesNotMatch(widget,/Qt.resolvedUrl\("build.sh"\)/);
console.log(`${passed} installer scenarios passed (mock host; real SHA-256 verification).`);
