const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'familiar-bar-'));
try {
  const config = path.join(tmp, 'config'), state = path.join(tmp, 'state');
  const bin = path.join(tmp, 'bin'), log = path.join(tmp, 'calls');
  fs.mkdirSync(path.join(config, 'omarchy/familiar-titlebars'), {recursive:true});
  fs.mkdirSync(bin);
  fs.writeFileSync(path.join(bin, 'omarchy'), '#!/bin/bash\nprintf "%s\\n" "$*" >> "$CALLS"\nexit "${FAIL:-0}"\n', {mode:0o755});
  const env = {...process.env, XDG_CONFIG_HOME:config, XDG_STATE_HOME:state, PATH:bin+':'+process.env.PATH, CALLS:log};
  const marker = path.join(state, 'familiar-desktop/bar-placement-pending');
  const owner = path.join(config, 'omarchy/familiar-titlebars/owner.json');
  function run(command, extra={}) {
    const r = spawnSync('bash', ['-euc', 'source ./bar-placement.sh; '+command], {env:{...env,...extra}, encoding:'utf8'});
    assert.equal(r.status, 0, r.stderr);
  }
  function layout(right) { fs.writeFileSync(path.join(config, 'omarchy/shell.json'), JSON.stringify({bar:{layout:{right}}})); }
  for (const agents of ['omarchy.agents', {id:'omarchy.agents'}]) {
    layout(['omarchy.tray', agents, 'omarchy.network']); fs.writeFileSync(log,'');
    run('familiar_prepare_bar_placement; familiar_apply_bar_placement');
    assert.match(fs.readFileSync(log,'utf8'), /--after omarchy.agents\n$/);
    assert.equal(fs.existsSync(marker),false);
  }
  // Ownership created during setup must not prevent retrying a pending placement.
  run('familiar_prepare_bar_placement'); fs.writeFileSync(owner,'{}');
  run('familiar_apply_bar_placement',{FAIL:'1'}); assert.ok(fs.existsSync(marker));
  run('familiar_apply_bar_placement'); assert.equal(fs.existsSync(marker),false);
  // Later repairs and updates preserve a user's custom location.
  fs.writeFileSync(log,''); run('familiar_prepare_bar_placement; familiar_apply_bar_placement');
  assert.equal(fs.readFileSync(log,'utf8'),'');
  fs.unlinkSync(owner); layout(['omarchy.network']);
  run('familiar_prepare_bar_placement; familiar_apply_bar_placement');
  assert.match(fs.readFileSync(log,'utf8'), /--section right --index 0\n$/);
  fs.writeFileSync(path.join(config, 'omarchy/shell.json'), JSON.stringify({bar:{layout:{left:['omarchy.agents'],right:['omarchy.network']}}}));
  fs.writeFileSync(log,'');
  run('familiar_prepare_bar_placement; familiar_apply_bar_placement');
  assert.match(fs.readFileSync(log,'utf8'), /--section right --index 0\n$/);
  assert.doesNotMatch(fs.readFileSync(log,'utf8'), /--after/);
  console.log('Bar placement: after Agents, absent/moved anchor, existing installs, and failed-placement retry passed.');
} finally { fs.rmSync(tmp,{recursive:true,force:true}); }
