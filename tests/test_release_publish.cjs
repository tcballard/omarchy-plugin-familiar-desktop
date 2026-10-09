// Exercise the real final-publication script without GitHub writes. In particular,
// a GITHUB_TOKEN release must upload its own assets before becoming public.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const {createHash} = require('node:crypto');
const script = path.resolve('scripts/publish-final-release.sh');
const sha = 'a'.repeat(40);
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'familiar-publish-test-'));
let count = 0;
try {
  for (const fault of ['', 'missing-artifact', 'wrong-source', 'unreviewed', 'bad-pin', 'wrong-run', 'readback', 'stale-main', 'existing-tag', 'bad-version', 'public-404']) {
    const dir = path.join(root, fault || 'healthy');
    fs.mkdirSync(path.join(dir, 'bin'), {recursive:true});
    fs.mkdirSync(path.join(dir, 'docs'));
    fs.mkdirSync(path.join(dir, 'bundle'));
    const write = (name, bytes, mode) => fs.writeFileSync(path.join(dir, name), bytes, {mode: mode || 0o644});
    write('manifest.json', JSON.stringify({version:'0.1.4'}));
    write('docs/v0.1.4.md', '# Familiar v0.1.4\n\n## Thanks\n\nContributors.\n');
    write('bundle/RELEASE-MANIFEST.json', JSON.stringify({version:'0.1.4',source:{commit:fault === 'wrong-source' ? 'b'.repeat(40) : sha},sourcePinsMatch:fault !== 'unreviewed'}));
    write('bundle/SOURCE-MANIFEST.json', JSON.stringify({source:{commit:sha}}));
    write('bundle/install.sh', `release_sha='${sha}'\n`);
    write('bundle/install-candidate.sh', `candidate_sha='${sha}'\n`);
    const binary = `#!/bin/sh\necho 'familiar-desktop ${fault === 'bad-version' ? '0.1.3' : '0.1.4'}'\n`;
    write('bundle/familiar-desktop-linux-x86_64', binary, 0o755);
    write('bundle/hyprbars-fixture.so', 'library\n');
    const checksum = name => createHash('sha256').update(fs.readFileSync(path.join(dir, 'bundle', name))).digest('hex') + '  ' + name + '\n';
    write('release-binaries.sha256', (fault === 'bad-pin' ? '0'.repeat(64)+'  familiar-desktop-linux-x86_64\n' : checksum('familiar-desktop-linux-x86_64')) + checksum('hyprbars-fixture.so'));
    write('bundle/SHA256SUMS', fs.readdirSync(path.join(dir, 'bundle')).map(checksum).join(''));
    write('bin/git', `#!/bin/bash
printf 'git %s\\n' "$*" >> "$FIXTURE/events"
case "$1" in
  rev-parse) echo "$SOURCE_SHA";;
  show-ref) [[ "$FAULT" == existing-tag ]];;
  tag|push) exit 0;;
  *) exit 9;;
esac
`, 0o755);
    write('bin/gh', `#!/usr/bin/env node
const fs=require('fs'),path=require('path');const a=process.argv.slice(2),d=process.env.FIXTURE,f=process.env.FAULT;
fs.appendFileSync(path.join(d,'events'),'gh '+a.join(' ')+'\\n');
const opt=k=>a[a.indexOf(k)+1];
if(a[0]==='api') {
 if(a[1].includes('/actions/runs/')) console.log(JSON.stringify({head_sha:process.env.SOURCE_SHA,event:'push',path:'.github/workflows/release.yml',status:'completed',conclusion:f==='wrong-run'?'failure':'success'}));
 else console.log(f==='stale-main'?'b'.repeat(40):process.env.SOURCE_SHA);
} else if(a[0]==='run' && a[1]==='download') {
 if(f==='missing-artifact') process.exit(1);
 fs.cpSync(path.join(d,'bundle'),opt('--dir'),{recursive:true});
} else if(a[0]==='release' && a[1]==='create') {
 if(!a.includes('--draft')) throw Error('Must upload to draft first');
 const upload=path.join(d,'uploaded');fs.mkdirSync(upload);
 const files=a.filter(x=>x.startsWith('/') && path.dirname(x).endsWith('/assets'));
 if(!files.length) throw Error('No assets uploaded');
 for(const x of files) fs.copyFileSync(x,path.join(upload,path.basename(x)));
} else if(a[0]==='release' && a[1]==='download') {
 fs.cpSync(path.join(d,'uploaded'),opt('--dir'),{recursive:true});
 if(f==='readback') fs.writeFileSync(path.join(opt('--dir'),'familiar-desktop-linux-x86_64'),'corrupt');
} else if(a[0]==='release' && a[1]==='edit') {
 if(!a.includes('--draft=false')) throw Error('Unexpected edit');
} else throw Error('Unexpected gh call: '+a.join(' '));
`, 0o755);
    // gh fixture uses the real node; only the final smoke command is stubbed.
    write('bin/node', `#!/bin/bash
if [[ "$1" == scripts/verify-release-download.cjs ]]; then
 echo "public smoke $*" >> "$FIXTURE/events"
 [[ "$FAULT" != public-404 ]]
else exec '${process.execPath}' "$@"; fi
`, 0o755);
    const result=spawnSync('bash',[script],{cwd:dir,encoding:'utf8',env:{...process.env,PATH:path.join(dir,'bin')+':'+process.env.PATH,SOURCE_SHA:sha,RELEASE_RUN_ID:'123',GH_REPO:'tcballard/omarchy-plugin-familiar-desktop',FIXTURE:dir,FAULT:fault}});
    const events=fs.readFileSync(path.join(dir,'events'),'utf8');
    assert.equal(result.status===0, fault==='', fault+'\n'+result.stderr);
    if(!fault) {
      assert.ok(events.indexOf('gh release create') < events.indexOf('gh release download'));
      assert.ok(events.indexOf('gh release download') < events.indexOf('gh release edit'));
      assert.ok(events.indexOf('gh release edit') < events.indexOf('public smoke'));
      assert.ok(events.includes('--tag v0.1.4 --repo tcballard/omarchy-plugin-familiar-desktop'));
    } else if(fault === 'public-404') assert.ok(events.includes('public smoke'));
    else {
      assert.ok(!events.includes('gh release edit'), 'Must not publish after '+fault);
      if(fault!=='readback') assert.ok(!events.includes('git tag'), 'Must validate before tagging: '+fault);
    }
    count++;
  }
  console.log(`${count} final-publication scenarios passed (no GitHub mutations).`);
} finally {fs.rmSync(root,{recursive:true,force:true});}
