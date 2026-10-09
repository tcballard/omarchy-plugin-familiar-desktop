// The release smoke check must fail loudly when the public onboarding URL is a
// 404, as happened for v0.1.3 (issue #79), and print the exact failing URL.
const fs=require('node:fs');const path=require('node:path');const os=require('node:os');const assert=require('node:assert/strict');
const {createHash}=require('node:crypto');const {spawnSync}=require('node:child_process');
const script=path.resolve(__dirname,'../scripts/verify-release-download.cjs');
const repository=process.cwd();
const version=JSON.parse(fs.readFileSync(path.join(repository,'manifest.json'))).version;
const abi='efb50993780079460b0cbed1363e2166a2de1d9f_aq_0.15_hu_0.14_hg_0.5_hc_0.1_hlg_0.6';
const backendAsset='familiar-desktop-linux-x86_64',libraryAsset=`hyprbars-linux-x86_64-${abi}.so`;
const digest=bytes=>createHash('sha256').update(bytes).digest('hex');
let passed=0;
const fixtures=[];
process.on("exit",()=>{ for(const dir of fixtures) fs.rmSync(dir,{recursive:true,force:true}); });
function fixture({pinsFault='',installerRelease='',manifestVersion=version}={}) {
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'familiar-smoke-'));
  fixtures.push(root);fs.mkdirSync(path.join(root,'temp'));
  const write=(name,bytes)=>{const file=path.join(root,name);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes);};
  const backend=`#!/bin/sh\nprintf 'familiar-desktop ${version}\\n'\n`;
  const library='fixture hyprbars library\n';
  const assets=path.join(root,'assets');fs.mkdirSync(assets);
  fs.writeFileSync(path.join(assets,backendAsset),backend);fs.chmodSync(path.join(assets,backendAsset),0o755);
  fs.writeFileSync(path.join(assets,libraryAsset),library);
  write('manifest.json',`${JSON.stringify({version:manifestVersion})}\n`);
  for(const installer of ['install-backend.sh','install-titlebars.sh'])
    write(installer,fs.readFileSync(path.join(repository,installer),'utf8').replace(/release='[^']+'/,installerRelease?`release='${installerRelease}'`:`release='v${version}'`));
  let pins=`${pinsFault==='backend'?'0'.repeat(64):digest(backend)}  ${backendAsset}\n${pinsFault==='library'?'0'.repeat(64):digest(library)}  ${libraryAsset}\n`;
  if(pinsFault==='duplicate')pins+=pins.split('\n')[0]+'\n';
  if(pinsFault==='malformed')pins=pins.replace(/^[0-9a-f]{64}/,'not-a-digest');
  if(pinsFault==='missing-library')pins=pins.split('\n').filter(line=>!line.endsWith(`  ${libraryAsset}`)).join('\n');
  write('release-binaries.sha256',pins);
  return {root,assets};
}
function smoke(f,{tag=`v${version}`,missing=''}={}) {
  const bin=path.join(f.root,'bin');fs.mkdirSync(bin);
  const urls=path.join(f.root,'urls');
  fs.writeFileSync(path.join(bin,'curl'),`#!/bin/bash\nfor arg; do [[ "$arg" != https://* ]] || url="$arg"; done\necho "$url" >> "$URLS"\nif [[ -n "$MISSING" && "$url" == *"$MISSING" ]]; then echo 'curl: (22) The requested URL returned error: 404' >&2; exit 22; fi\ncp -- "$ASSETS/\${url##*/}" "\${@: -1}"\n`,{mode:0o755});
  const result=spawnSync(process.execPath,[script,'--tag',tag,'--repo','tcballard/omarchy-plugin-familiar-desktop','--root',f.root,'--curl',path.join(bin,'curl')],{encoding:'utf8',env:{...process.env,PATH:bin+':/usr/bin:/bin',ASSETS:f.assets,URLS:urls,MISSING:missing,TMPDIR:path.join(f.root,"temp")}});
  assert.deepEqual(fs.readdirSync(path.join(f.root,'temp')),[], 'Downloaded temporary files must be cleaned up on success and failure');
  return result;
}
function scenario(name,check){check();passed++;console.log(`${name}.`);}
// Healthy release: both onboarding URLs resolve and match the reviewed pins.
let f=fixture();
let r=smoke(f);
assert.equal(r.status,0,r.stderr);
assert.match(r.stdout,/Verified 2 onboarding download URLs/);
const requested=fs.readFileSync(path.join(f.root,'urls'),'utf8').split('\n').filter(Boolean);
assert.deepEqual(requested,[`https://github.com/tcballard/omarchy-plugin-familiar-desktop/releases/download/v${version}/${backendAsset}`,`https://github.com/tcballard/omarchy-plugin-familiar-desktop/releases/download/v${version}/${libraryAsset}`].sort());
passed++;console.log('Healthy release: both onboarding URLs downloaded and pinned digests verified.');
// The exact v0.1.3 failure: the release page exists but the asset 404s.
f=fixture();r=smoke(f,{missing:backendAsset});
assert.notEqual(r.status,0);
assert.ok(r.stderr.includes(`https://github.com/tcballard/omarchy-plugin-familiar-desktop/releases/download/v${version}/${backendAsset}`),r.stderr);
assert.match(r.stderr,/404|asset is missing/);
passed++;console.log('Missing backend asset fails with the exact onboarding URL.');
f=fixture();r=smoke(f,{missing:libraryAsset});
assert.notEqual(r.status,0);
assert.ok(r.stderr.includes(`releases/download/v${version}/${libraryAsset}`),r.stderr);
passed++;console.log('Missing Hyprbars asset fails with the exact onboarding URL.');
for(const pinsFault of ['backend','library','duplicate','malformed','missing-library']) {
  r=smoke(fixture({pinsFault}));
  assert.notEqual(r.status,0,pinsFault);
  assert.match(r.stderr,/Checksum mismatch|reviewed source digest|release-binaries\.sha256/,pinsFault);
  passed++;
}
console.log('Digest mismatch and malformed pin files are rejected.');
// A stale installer release pin would silently download a different release.
r=smoke(fixture({installerRelease:'v0.0.6'}));
assert.notEqual(r.status,0);
assert.match(r.stderr,new RegExp(`install-backend\\.sh downloads v0\\.0\\.6, not v${version}`));
passed++;console.log('Installer/tag release mismatch is rejected.');
r=smoke(fixture(),{tag:'v9.9.9'});
assert.notEqual(r.status,0);
assert.match(r.stderr,/does not match manifest\.json/);
passed++;console.log('Tag/manifest version mismatch is rejected.');
r=smoke(fixture(),{tag:''});
assert.notEqual(r.status,0);
assert.match(r.stderr,/Usage/);
passed++;console.log('Missing --tag is rejected.');
for(const installer of ['install-backend.sh','install-titlebars.sh']) {
  f=fixture();
  const file=path.join(f.root,installer);
  fs.writeFileSync(file,fs.readFileSync(file,'utf8').replace('github.com/tcballard/', 'github.com/wrong-owner/'));
  r=smoke(f);assert.notEqual(r.status,0);assert.match(r.stderr,/download base differs/);passed++;
}
f=fixture();fs.appendFileSync(path.join(f.root,'release-binaries.sha256'),'0'.repeat(64)+'  ../outside\n');
r=smoke(f);assert.notEqual(r.status,0);assert.match(r.stderr,/Malformed/);passed++;
console.log(`${passed} release smoke-check scenarios passed.`);
