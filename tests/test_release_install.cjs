// Exercise the actual release executable through the actual binary installer.
const fs=require('node:fs');const path=require('node:path');const os=require('node:os');const assert=require('node:assert/strict');const {spawnSync}=require('node:child_process');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'familiar-release-'));
try {
 fs.copyFileSync('install-backend.sh',path.join(root,'install-backend.sh'));
 const tools=path.join(root,'tools');fs.mkdirSync(tools);
 fs.writeFileSync(path.join(tools,'curl'),'#!/bin/bash\nfor arg; do [[ "$arg" != https://* ]] || url="$arg"; done\ncp -- "$ASSETS/${url##*/}" "${@: -1}"\n',{mode:0o755});
 for(const name of ['cargo','rustup','clippy','cc','make'])fs.writeFileSync(path.join(tools,name),'#!/bin/bash\necho "Unexpected development dependency" >&2; exit 99\n',{mode:0o755});
 const p=spawnSync('/bin/bash',[path.join(root,'install-backend.sh')],{encoding:'utf8',env:{HOME:root,PATH:tools+':/usr/bin:/bin',ASSETS:path.resolve('release-assets')}});
 assert.equal(p.status,0,p.stderr);assert.match(p.stdout,/0\.0\.3 installed and SHA-256 verified/);
 const installed=spawnSync(path.join(root,'bin/familiar-desktop'),['--version'],{encoding:'utf8',env:{HOME:root,PATH:'/usr/bin:/bin'}});
 assert.equal(installed.status,0,installed.stderr);assert.equal(installed.stdout.trim(),'familiar-desktop 0.0.4');
 console.log('Real static release binary installed and executed without development tools.');
}finally{fs.rmSync(root,{recursive:true,force:true});}
