// Packaging regressions use real Git/Cargo with disposable executable/library fixtures.
if (process.argv.includes('--fixtures')) {
 const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),assert=require('node:assert/strict');
 const {createHash}=require('node:crypto'),{spawnSync,execFileSync}=require('node:child_process');
 const repository=process.cwd(),binary='familiar-desktop-linux-x86_64',library='hyprbars-linux-x86_64-fixture.so';
 const digest=bytes=>createHash('sha256').update(bytes).digest('hex');
 function fixture({backendMismatch=false,libraryMismatch=false,pinFault='',wrongVersion=false,missingLibrary=false}={}) {
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'familiar-packaging-'));
  const write=(name,bytes)=>{const file=path.join(root,name);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes);};
  const backend=`#!/bin/sh\nprintf 'familiar-desktop ${wrongVersion?'9.9.9':'0.1.2'}\\n'\n`;
  const bars='fixture library\n';
  write('backend-built',backend);fs.chmodSync(path.join(root,'backend-built'),0o755);
  if(!missingLibrary)write('hyprbars-assets/'+library,bars);
  write('hyprbars-assets/BUILD.json','{"fixture":true}\n');
  write('manifest.json','{"version":"0.1.2"}\n');
  write('backend/Cargo.toml','[package]\nname="familiar-desktop"\nversion="0.1.2"\nedition="2024"\n');
  write('backend/src/main.rs','fn main() {}\n');
  for(const name of ['scripts/prepare-release.cjs','scripts/install-candidate.sh','install.sh','docs/XPS-TEST.md','docs/RELEASE-0.1.2.md','docs/v0.1.2.md','docs/ROLLBACK.md'])
   write(name,fs.readFileSync(path.join(repository,name)));
  let pins=`${backendMismatch?'0'.repeat(64):digest(backend)}  ${binary}\n${libraryMismatch?'0'.repeat(64):digest(bars)}  ${library}\n`;
  if(pinFault==='duplicate')pins+=pins.split('\n')[0]+'\n';
  if(pinFault==='malformed')pins=pins.replace(/^[0-9a-f]{64}/,'not-a-digest');
  if(pinFault==='missing')pins=pins.split('\n').slice(1).join('\n');
  if(pinFault==='duplicate-library')pins+=pins.split('\n')[1]+'\n';
  if(pinFault==='malformed-library')pins=pins.replace(`${digest(bars)}  ${library}`,`not-a-digest  ${library}`);
  if(pinFault==='missing-library')pins=pins.split('\n').filter(line=>!line.endsWith(`  ${library}`)).join('\n');
  write('release-binaries.sha256',pins);
  const run=(command,args)=>execFileSync(command,args,{cwd:root,encoding:'utf8',stdio:['ignore','pipe','pipe']});
  run('cargo',['generate-lockfile','--manifest-path','backend/Cargo.toml']);
  run('git',['init','-q']);run('git',['add','.']);
  run('git',['-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-qm','Packaging fixture']);
  const sha=run('git',['rev-parse','HEAD']).trim();
  return {root,pins,sha,run,package(ci){return spawnSync(process.execPath,['scripts/prepare-release.cjs','backend-built',...(ci?['--ci']:[])],{cwd:root,encoding:'utf8'});}};
 }
 const scenarios=[
  {name:'unreleased backend',options:{backendMismatch:true},ci:true,success:true,reviewed:false},
  {name:'unreleased library',options:{libraryMismatch:true},ci:true,success:true,reviewed:false},
  {name:'reviewed CI build',options:{},ci:true,success:true,reviewed:true},
  {name:'reviewed strict build',options:{},ci:false,success:true,reviewed:true},
  {name:'strict backend mismatch',options:{backendMismatch:true},ci:false,success:false},
  {name:'strict library mismatch',options:{libraryMismatch:true},ci:false,success:false},
  ...['duplicate','malformed','missing','duplicate-library','malformed-library','missing-library'].map(pinFault=>({name:`CI ${pinFault} pin`,options:{pinFault},ci:true,success:false})),
  {name:'CI wrong version',options:{backendMismatch:true,wrongVersion:true},ci:true,success:false},
  {name:'CI missing library',options:{backendMismatch:true,missingLibrary:true},ci:true,success:false}
 ];
 for(const scenario of scenarios) {
  const f=fixture(scenario.options);
  try {
   const result=f.package(scenario.ci);
   if(!scenario.success) {
    assert.notEqual(result.status,0,scenario.name);
    console.log(`Packaging rejected ${scenario.name}.`);
    continue;
   }
   assert.equal(result.status,0,`${scenario.name}: ${result.stderr}`);
   const dir=path.join(f.root,'release-assets');
   const manifest=JSON.parse(fs.readFileSync(path.join(dir,'RELEASE-MANIFEST.json')));
   assert.equal(manifest.sourcePinsMatch,scenario.reviewed,scenario.name);
   assert.equal(manifest.source.commit,f.sha);
   assert.equal(f.run('tar',['-xOf',path.join(dir,'familiar-desktop-0.1.2-source.tar.gz'),'familiar-desktop-0.1.2/release-binaries.sha256']),f.pins);
   assert.equal(fs.readFileSync(path.join(f.root,'release-binaries.sha256'),'utf8'),f.pins);
   for(const name of ['install.sh','install-candidate.sh','XPS-TEST.md','RELEASE-0.1.2.md','v0.1.2.md','ROLLBACK.md'])
    assert.equal(fs.existsSync(path.join(dir,name)),scenario.reviewed,`${scenario.name}: ${name}`);
   assert.deepEqual(fs.readFileSync(path.join(dir,binary)),fs.readFileSync(path.join(f.root,'backend-built')));
   assert.deepEqual(fs.readFileSync(path.join(dir,library)),Buffer.from('fixture library\n'));
   const checks=spawnSync('sha256sum',['--check','--strict','SHA256SUMS'],{cwd:dir,encoding:'utf8'});
   assert.equal(checks.status,0,checks.stderr);
   fs.appendFileSync(path.join(dir,binary),'tampered\n');
   assert.notEqual(spawnSync('sha256sum',['--check','--strict','SHA256SUMS'],{cwd:dir,encoding:'utf8'}).status,0);
   console.log(`Packaging accepted ${scenario.name}; reviewed=${scenario.reviewed}.`);
  } finally {fs.rmSync(f.root,{recursive:true,force:true});}
 }
 return;
}

// Exercise the actual release executable through the actual binary installer.
const fs=require('node:fs');const path=require('node:path');const os=require('node:os');const assert=require('node:assert/strict');const {createHash}=require('node:crypto');const {spawnSync,execFileSync}=require('node:child_process');
const ci=process.argv.includes('--ci');
const version=JSON.parse(fs.readFileSync('manifest.json')).version;
const manifest=JSON.parse(fs.readFileSync('release-assets/RELEASE-MANIFEST.json'));
assert.equal(manifest.sourcePinsMatch,!ci,'Validation-only smoke must be explicit; default smoke requires committed pins.');
assert.equal(manifest.source.commit,execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim());
for(const name of ['install.sh','install-candidate.sh','XPS-TEST.md','RELEASE-0.1.2.md','v0.1.2.md','ROLLBACK.md'])
 assert.equal(fs.existsSync(path.join('release-assets',name)),!ci,name);
const root=fs.mkdtempSync(path.join(os.tmpdir(),'familiar-release-'));
try {
 if(ci) {
  // Only this disposable fixture trusts freshly built assets, never the checkout.
  const assets=fs.readdirSync('release-assets').filter(name=>name==='familiar-desktop-linux-x86_64'||/^hyprbars-linux-x86_64-.+\.so$/.test(name));
  const pins=assets.map(name=>`${createHash('sha256').update(fs.readFileSync(path.join('release-assets',name))).digest('hex')}  ${name}\n`).join('');
  fs.writeFileSync(path.join(root,'release-binaries.sha256'),pins);
 } else fs.copyFileSync('release-binaries.sha256',path.join(root,'release-binaries.sha256'));
 fs.copyFileSync('install-backend.sh',path.join(root,'install-backend.sh'));
 const tools=path.join(root,'tools');fs.mkdirSync(tools);
 fs.writeFileSync(path.join(tools,'curl'),'#!/bin/bash\nfor arg; do [[ "$arg" != https://* ]] || url="$arg"; done\ncp -- "$ASSETS/${url##*/}" "${@: -1}"\n',{mode:0o755});
 for(const name of ['cargo','rustup','clippy','cc','make'])fs.writeFileSync(path.join(tools,name),'#!/bin/bash\necho "Unexpected development dependency" >&2; exit 99\n',{mode:0o755});
 const p=spawnSync('/bin/bash',[path.join(root,'install-backend.sh')],{encoding:'utf8',env:{HOME:root,PATH:tools+':/usr/bin:/bin',ASSETS:path.resolve('release-assets')}});
 assert.equal(p.status,0,p.stderr);assert.ok(p.stdout.includes(`${version} installed and SHA-256 verified`));
 const installed=spawnSync(path.join(root,'bin/familiar-desktop'),['--version'],{encoding:'utf8',env:{HOME:root,PATH:'/usr/bin:/bin'}});
 assert.equal(installed.status,0,installed.stderr);assert.equal(installed.stdout.trim(),`familiar-desktop ${version}`);
 fs.copyFileSync('install-titlebars.sh',path.join(root,'install-titlebars.sh'));
 const abi='efb50993780079460b0cbed1363e2166a2de1d9f_aq_0.15_hu_0.14_hg_0.5_hc_0.1_hlg_0.6';
 fs.writeFileSync(path.join(tools,'hyprctl'),`#!/bin/bash\necho 'Version ABI string: ${abi}'\n`,{mode:0o755});
 fs.writeFileSync(path.join(tools,'hyprpm'),'#!/bin/bash\nexit 99\n',{mode:0o755});
 const bars=spawnSync('/bin/bash',[path.join(root,'install-titlebars.sh')],{encoding:'utf8',env:{HOME:root,PATH:tools+':/usr/bin:/bin',ASSETS:path.resolve('release-assets')}});
 assert.equal(bars.status,0,bars.stderr);
 assert.deepEqual(fs.readFileSync(bars.stdout.trim()),fs.readFileSync(path.resolve('release-assets',`hyprbars-linux-x86_64-${abi}.so`)));
 console.log('Actual Hyprbars release asset installed and verified without build tools (runtime loading not tested).');
 console.log(`Real static ${ci?'validation-only':'release'} binary installed and executed without development tools.`);
}finally{fs.rmSync(root,{recursive:true,force:true});}
