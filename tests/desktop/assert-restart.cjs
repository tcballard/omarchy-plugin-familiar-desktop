const fs = require('node:fs'), assert = require('node:assert/strict');
const [evidence, config] = process.argv.slice(2);
function instance(name) {
  const rows = JSON.parse(fs.readFileSync(`${evidence}/${name}.json`));
  const matches = rows.filter(row=>String(row.config_path).startsWith(config+'/'));
  assert.equal(matches.length,1,`${name}: expected exactly one real shell`);
  assert.ok(Number.isInteger(matches[0].pid) && matches[0].pid > 0, 'missing shell PID');
  return matches[0].pid;
}
assert.notEqual(instance('shell-before'),instance('shell-after'),'restart must replace the shell process');
