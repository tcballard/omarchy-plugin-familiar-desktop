// Development artifacts are intentionally separate from versioned release assets.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {execFileSync} = require('node:child_process');
const [input, output] = process.argv.slice(2);
if (!input || !output) throw Error('Usage: prepare-dev-bundle.cjs DOWNLOADED OUTPUT');
const sha = execFileSync('git', ['rev-parse', 'HEAD'], {encoding:'utf8'}).trim();
if (sha !== process.env.BUILD_SOURCE_SHA) throw Error('Unexpected checkout');
const run = process.env.GITHUB_RUN_ID, attempt = process.env.GITHUB_RUN_ATTEMPT;
if (!/^\d+$/.test(run || '') || !/^\d+$/.test(attempt || '')) throw Error('Missing CI run identity');
const candidates = fs.readdirSync(input).map(n => path.join(input,n)).filter(p => fs.existsSync(path.join(p,'RELEASE-MANIFEST.json')));
if (candidates.length !== 1) throw Error('Expected one complete binary bundle');
const dir = candidates[0];
execFileSync('sha256sum', ['--check','--strict','SHA256SUMS'], {cwd:dir});
const manifest = JSON.parse(fs.readFileSync(path.join(dir,'RELEASE-MANIFEST.json')));
if (manifest.source.commit !== sha) throw Error('Binary source mismatch');
fs.mkdirSync(output, {recursive:true});
if (fs.readdirSync(output).length) throw Error('Output must be empty');
const digest = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const assets = {};
for (const item of manifest.artifacts) {
  if (!/^(familiar-desktop-linux-x86_64|hyprbars-linux-x86_64-[a-zA-Z0-9_.-]+\.so)$/.test(item.name)) continue;
  if (digest(path.join(dir,item.name)) !== item.sha256) throw Error('Manifest digest mismatch');
  fs.copyFileSync(path.join(dir,item.name),path.join(output,item.name));
  assets[item.name] = item.sha256;
}
if (Object.keys(assets).length !== 2 || !assets['familiar-desktop-linux-x86_64']) throw Error('Expected backend and one supported Hyprbars library');
fs.writeFileSync(path.join(output,'DEV-BUILD.json'), JSON.stringify({schemaVersion:1,channel:'development',commit:sha,version:manifest.version,repository:'tcballard/omarchy-plugin-familiar-desktop',runId:run,runAttempt:attempt,assets},null,2)+'\n');
fs.writeFileSync(path.join(output,'install-dev.sh'),fs.readFileSync('scripts/install-dev.sh','utf8').replace('@SOURCE_SHA@',sha));
fs.copyFileSync('docs/DEVELOPMENT.md',path.join(output,'DEVELOPMENT.md'));
fs.writeFileSync(path.join(output,'SHA256SUMS'),fs.readdirSync(output).sort().map(n=>`${digest(path.join(output,n))}  ${n}\n`).join(''));
console.log(`Development build ${sha}; run ${run}, attempt ${attempt}. No release created.`);
