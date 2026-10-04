// Exercise the actual release executable through the actual binary installer.
const fs=require('node:fs');const path=require('node:path');const os=require('node:os');const assert=require('node:assert/strict');const {spawnSync}=require('node:child_process');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'familiar-release-'));
try {
 fs.copyFileSync('install-backend.sh',path.join(root,'install-backend.sh'));
 const tools=path.join(root,'tools');fs.mkdirSync(tools);
 fs.writeFileSync(path.join(tools,'curl'),'#!/bin/bash\nfor arg; do [[ "$arg" != https://* ]] || url="$arg"; done\ncp -- "$ASSETS/${url##*/}" "${@: -1}"\n',{mode:0o755});
 for(const name of ['cargo','rustup','clippy','cc','make'])fs.writeFileSync(path.join(tools,name),'#!/bin/bash\necho "Unexpected development dependency" >&2; exit 99\n',{mode:0o755});
 const p=spawnSync('/bin/bash',[path.join(root,'install-backend.sh')],{encoding:'utf8',env:{HOME:root,PATH:tools+':/usr/bin:/bin',ASSETS:path.resolve('release-assets')}});
 assert.equal(p.status,0,p.stderr);assert.match(p.stdout,/0\.1\.0-rc\.2 installed and SHA-256 verified/);
 const installed=spawnSync(path.join(root,'bin/familiar-desktop'),['--version'],{encoding:'utf8',env:{HOME:root,PATH:'/usr/bin:/bin'}});
 assert.equal(installed.status,0,installed.stderr);assert.equal(installed.stdout.trim(),'familiar-desktop 0.1.0-rc.2');
 fs.copyFileSync('install-titlebars.sh',path.join(root,'install-titlebars.sh'));
 const abi='efb50993780079460b0cbed1363e2166a2de1d9f_aq_0.15_hu_0.14_hg_0.5_hc_0.1_hlg_0.6';
 fs.writeFileSync(path.join(tools,'hyprctl'),`#!/bin/bash\necho 'Version ABI string: ${abi}'\n`,{mode:0o755});
 fs.writeFileSync(path.join(tools,'hyprpm'),'#!/bin/bash\nexit 99\n',{mode:0o755});
 const bars=spawnSync('/bin/bash',[path.join(root,'install-titlebars.sh')],{encoding:'utf8',env:{HOME:root,PATH:tools+':/usr/bin:/bin',ASSETS:path.resolve('release-assets')}});
 assert.equal(bars.status,0,bars.stderr);
 assert.deepEqual(fs.readFileSync(bars.stdout.trim()),fs.readFileSync(path.resolve('release-assets',`hyprbars-linux-x86_64-${abi}.so`)));
 console.log('Actual Hyprbars release asset installed and verified without build tools (runtime loading not tested).');
 console.log('Real static release binary installed and executed without development tools.');
}finally{fs.rmSync(root,{recursive:true,force:true});}
