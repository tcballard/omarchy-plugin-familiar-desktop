const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const assert=require('node:assert/strict');
const {createHash}=require('node:crypto');
const {execFileSync,spawnSync}=require('node:child_process');
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'familiar-dev-bundle-'));
const sha=execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim();
const input=path.join(temp,'downloaded'),dir=path.join(input,'familiar-desktop-packaging-validation');
fs.mkdirSync(dir,{recursive:true});
const assets=['familiar-desktop-linux-x86_64','hyprbars-linux-x86_64-fixture.so'];
const digest=n=>createHash('sha256').update(fs.readFileSync(path.join(dir,n))).digest('hex');
for(const name of assets)fs.writeFileSync(path.join(dir,name),name);
const manifest={source:{commit:sha},version:'0.1.2',artifacts:assets.map(name=>({name,sha256:digest(name)}))};
function metadata() {
 fs.writeFileSync(path.join(dir,'RELEASE-MANIFEST.json'),JSON.stringify(manifest));
 fs.writeFileSync(path.join(dir,'SHA256SUMS'),[...assets,'RELEASE-MANIFEST.json'].map(n=>`${digest(n)}  ${n}\n`).join(''));
}
const env={...process.env,BUILD_SOURCE_SHA:sha,GITHUB_RUN_ID:'123',GITHUB_RUN_ATTEMPT:'2'};
function run(label,extra={}) {return spawnSync('node',['scripts/prepare-dev-bundle.cjs',input,path.join(temp,label)],{env:{...env,...extra},encoding:'utf8'});}
try {
 metadata();const result=run('good');assert.equal(result.status,0,result.stderr);
 const receipt=JSON.parse(fs.readFileSync(path.join(temp,'good/DEV-BUILD.json')));
 assert.equal(receipt.commit,sha);assert.equal(receipt.runAttempt,'2');assert.equal(receipt.channel,'development');
 assert.equal(receipt.assets[assets[0]],digest(assets[0]));
 assert.match(fs.readFileSync(path.join(temp,'good/install-dev.sh'),'utf8'),new RegExp(`source_sha='${sha}'`));
 execFileSync('sha256sum',['--check','--strict','SHA256SUMS'],{cwd:path.join(temp,'good')});
 assert.notEqual(run('head-mismatch',{BUILD_SOURCE_SHA:'a'.repeat(40)}).status,0);
 assert.notEqual(run('no-run',{GITHUB_RUN_ID:''}).status,0);
 manifest.source.commit='b'.repeat(40);metadata();assert.notEqual(run('source-mismatch').status,0);
 manifest.source.commit=sha;metadata();fs.appendFileSync(path.join(dir,assets[0]),'corrupt');assert.notEqual(run('transport').status,0);
 metadata();assert.notEqual(run('manifest-mismatch').status,0);
 console.log('Development packaging passed: exact source/run, checksums, receipt, mismatched source and corrupt assets.');
} finally {fs.rmSync(temp,{recursive:true,force:true});}
