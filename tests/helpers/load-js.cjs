// Load QML library modules through their real imports, without editing sources.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
module.exports = function loadJS(filename, cache = new Map()) {
  const file = path.resolve(filename);
  if (cache.has(file)) return cache.get(file);
  const scope = vm.createContext({console});
  cache.set(file, scope);
  let source = fs.readFileSync(file, 'utf8').replace(/^\.pragma library\s*/m, '');
  source = source.replace(/^\.import "([^"]+)" as (\w+)\s*$/gm, (_, relative, alias) => {
    scope[alias] = module.exports(path.resolve(path.dirname(file), relative), cache);
    return '';
  });
  vm.runInContext(source, scope, {filename: file});
  return scope;
};
