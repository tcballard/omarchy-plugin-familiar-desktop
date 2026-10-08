const fs = require('node:fs'), path = require('node:path');
const [omarchy, home] = process.argv.slice(2);
const manifests = [];
function walk(dir) {
  for (const entry of fs.readdirSync(dir, {withFileTypes:true})) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(file);
    else if (entry.name.endsWith('manifest.json')) manifests.push(JSON.parse(fs.readFileSync(file)));
  }
}
walk(path.join(omarchy, 'shell/plugins'));
const disabledPlugins = [...new Set(manifests.map(m=>m.id).filter(id=>id && id !== 'omarchy.bar'))];
fs.writeFileSync(path.join(home,'.config/omarchy/shell.json'), JSON.stringify({version:1,
  bar:{position:'top',layout:{left:[],center:[],right:[]}}, plugins:[],disabledPlugins},null,2));
