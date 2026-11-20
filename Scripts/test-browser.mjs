// SPDX-License-Identifier: Apache-2.0
// Real Chromium test of CLI output, with page scripts disabled by CDP.
import { spawn, execFileSync } from 'node:child_process';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';

const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const browser = process.env.SWIFTMD_CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const cli = process.env.SWIFTMD_CLI || join(root, 'Tools/SwiftMDCLI/.build/debug/swift-md');
const node = process.env.SWIFTMD_NODE || process.execPath;
const katex = process.env.SWIFTMD_KATEX || join(root, 'Tools/NodeDependencies/node_modules/katex');
const pele = process.env.SWIFTMD_PELE || join(root, 'Tools/NodeDependencies/node_modules/pele/dist/pele.js');
const input = `# Browser test

${process.env.SWIFTMD_MARKDOWN_MATH_BROWSER ? 'Inline $x^2$\u0301 text.\n\n$$\n\\frac{x}{2}\n$$\n' : ''}
| Key | Value |
| --- | --- |
| test | [example](https://example.com) |

\`\`\`swift
let greeting = "Hello"
\`\`\`

\`\`\`math
x^2 + y^2 = z^2
\`\`\`

\`\`\`mermaid
flowchart LR
accTitle: Example diagram
accDescr: Two connected nodes
A[Start] --> B[Finish]
\`\`\`

\`\`\`mermaid
flowchart LR
accTitle: Example diagram
accDescr: Two connected nodes
A[Start] --> B[Finish]
\`\`\`
`;
const dir = await mkdtemp(join(tmpdir(), 'swiftmd-browser-'));
let chrome;
try {
  let rendered = execFileSync(cli, [...(process.env.SWIFTMD_MARKDOWN_MATH_BROWSER ? ['--markdown-math'] : []), '--strict', '--document', '--highlight', '--katex-node', node, '--katex-module', katex, '--pele-node', node, '--pele-module', pele, '--svg-prefix', 'browser-test'], { input, encoding: 'utf8' });
  // Optional probe fragments exercise the direct Swift KaTeX adapter API.
  if (process.env.SWIFTMD_MATHML_PROBE) {
    const probe = JSON.parse(await readFile(process.env.SWIFTMD_MATHML_PROBE, 'utf8'));
    rendered = rendered.replace('</body>', `${probe.composed}</body>`);
  }
  // If page scripts unexpectedly execute, this sentinel exposes the failure.
  const document = rendered.replace('</head>', '<style>body{font:16px sans-serif;margin:24px} svg{display:block;margin:12px 0} .hljs-keyword{color:#7b1fa2}</style><script>window.__swiftmdPageScriptRan=true</script></head>');
  const file = join(dir, 'test.html'); await writeFile(file, document);
  const profile = join(dir, 'profile');
  chrome = spawn(browser, ['--headless=new', '--disable-gpu', '--no-first-run', '--no-default-browser-check', '--remote-debugging-port=0', '--user-data-dir=' + profile, 'about:blank'], { stdio: 'ignore' });
  let port;
  for (let i = 0; i < 200; i++) {
    if (chrome.exitCode !== null) throw Error(`Chromium exited: ${chrome.exitCode}`);
    try { port = (await readFile(join(profile, 'DevToolsActivePort'), 'utf8')).split('\n')[0]; break; } catch { await new Promise(r => setTimeout(r, 50)); }
  }
  if (!port) throw Error('Chromium debugging endpoint did not start');
  const targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  const page = targets.find(t => t.type === 'page');
  if (!page) throw Error('Chromium did not create a page');
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; });
  let next = 0; const pending = new Map(); let load; const networkRequests = [];
  let loaded = new Promise(resolve => { load = resolve; });
  ws.onmessage = e => { const m = JSON.parse(e.data); if (m.id && pending.has(m.id)) { const [resolve, reject] = pending.get(m.id); pending.delete(m.id); m.error ? reject(Error(m.error.message)) : resolve(m.result); } else if (m.method === 'Page.loadEventFired') load(); else if (m.method === 'Network.requestWillBeSent') networkRequests.push(m.params.request.url); };
  const send = (method, params = {}) => new Promise((resolve, reject) => { const id = ++next; pending.set(id, [resolve, reject]); ws.send(JSON.stringify({id, method, params})); });
  await send('Page.enable');
  await send('Network.enable');
  await send('Emulation.setScriptExecutionDisabled', {value: true});
  await send('Page.navigate', {url: pathToFileURL(file).href});
  await Promise.race([loaded, new Promise((_, reject) => { const timer = setTimeout(() => reject(Error('page load timeout')), 10000); timer.unref(); })]);
  const gfmCases = JSON.parse(execFileSync('python3', [join(root, 'Scripts/analyze-published-gfm.py'), '--browser-cases'], {encoding:'utf8', env:{...process.env, SWIFTMD_CLI:cli}}));
  const expression = `(() => {
    const maths = [...document.querySelectorAll('math')]; const math = maths[0]; const svgs = [...document.querySelectorAll('svg')];
    const box = el => { const r = el.getBoundingClientRect(); return {width:r.width,height:r.height}; };
    const inspect = html => {
      const root = document.createElement('div'); root.innerHTML = html;
      const visit = n => n.nodeType === 3 ? ['text', n.nodeValue] : n.nodeType === 8 ? ['comment', n.nodeValue] : [n.localName, [...n.attributes].map(a => [a.name, a.value]).sort((a,b) => a[0].localeCompare(b[0])), [...n.childNodes].map(visit)];
      return {tree:[...root.childNodes].map(visit), text:root.textContent};
    };
    const gfm = ${JSON.stringify(gfmCases)}.map(({number, expected, actual}) => {
      const e = inspect(expected), a = inspect(actual);
      return {number, sameDOM:JSON.stringify(e.tree) === JSON.stringify(a.tree), expectedText:e.text, actualText:a.text};
    });
    const mathProbe = id => { const el = document.querySelector(id + ' math'); return el && {namespace:el.namespaceURI, display:el.getAttribute('display'), box:box(el)}; };
    return { scriptRan: window.__swiftmdPageScriptRan === true, gfm, combiningMark:document.body.textContent.includes('\u0301'),
      inlineProbe:mathProbe('#swiftmd-inline-math'), displayProbe:mathProbe('#swiftmd-display-math'),
      math: math && {namespace:math.namespaceURI, box:box(math), text:math.textContent},
      maths: maths.map(m => ({namespace:m.namespaceURI, display:m.getAttribute('display'), box:box(m)})),
      svgs: svgs.map(s => ({namespace:s.namespaceURI, viewBox:s.getAttribute('viewBox'), id:s.id, labelledby:s.getAttribute('aria-labelledby'), describedby:s.getAttribute('aria-describedby'), title:s.querySelector('title')?.textContent, desc:s.querySelector('desc')?.textContent, box:box(s), geometry:s.querySelector('path')?.getBBox().width, text:s.textContent})),
      table:!!document.querySelector('table'), highlighted:!!document.querySelector('.hljs-keyword'),
      scriptsInOutput:${JSON.stringify(rendered.includes('<script'))} };
  })()`;
  const evaluation = await send('Runtime.evaluate', {expression, returnByValue:true});
  if (evaluation.exceptionDetails || !evaluation.result.value) throw Error('DOM inspection failed: ' + JSON.stringify(evaluation));
  const report = evaluation.result.value;
  report.networkRequests = networkRequests;
  const expectedGfm = new Map([[279, true], [280, true], [649, false], [650, false]]);
  if (report.gfm.length !== expectedGfm.size || report.gfm.some(c => c.sameDOM !== expectedGfm.get(c.number))) throw Error('Unexpected GFM browser DOM comparison: ' + JSON.stringify(report.gfm));
  if (networkRequests.some(url => url !== pathToFileURL(file).href)) throw Error('Unexpected browser request: ' + JSON.stringify(networkRequests));
  if (process.env.SWIFTMD_MARKDOWN_MATH_BROWSER && (!report.combiningMark || report.maths.length < 3 || report.maths.slice(0, 3).some(m => m.namespace !== 'http://www.w3.org/1998/Math/MathML' || m.box.width <= 0 || m.box.height <= 0) || report.maths[0].display !== null || report.maths[1].display !== 'block' || report.maths[2].display !== 'block')) throw Error('Markdown math failed: ' + JSON.stringify(report));
  if (process.env.SWIFTMD_MATHML_PROBE && [report.inlineProbe, report.displayProbe].some(p => !p || p.namespace !== 'http://www.w3.org/1998/Math/MathML' || p.box.width <= 0 || p.box.height <= 0)) throw Error('MathML probe failed: ' + JSON.stringify(report));
  if (process.env.SWIFTMD_MATHML_PROBE && (report.inlineProbe.display !== null || report.displayProbe.display !== 'block')) throw Error('Incorrect MathML display modes: ' + JSON.stringify(report));
  if (report.scriptRan || report.scriptsInOutput || !report.table || !report.highlighted || report.math?.namespace !== 'http://www.w3.org/1998/Math/MathML' || report.math.box.width <= 0 || report.math.box.height <= 0 || report.svgs.length !== 2 || report.svgs.some(s => s.namespace !== 'http://www.w3.org/2000/svg' || !s.viewBox || s.box.width <= 0 || s.box.height <= 0 || !s.geometry || s.labelledby !== s.id + '-title' || s.describedby !== s.id + '-desc' || s.title !== 'Example diagram' || s.desc !== 'Two connected nodes' || !s.text.includes('Start') || !s.text.includes('Finish')) || report.svgs[0].id === report.svgs[1].id) throw Error('Browser assertions failed: ' + JSON.stringify(report));
  const screenshot = await send('Page.captureScreenshot', {format:'png'});
  if (process.env.SWIFTMD_BROWSER_SCREENSHOT) await writeFile(process.env.SWIFTMD_BROWSER_SCREENSHOT, Buffer.from(screenshot.data, 'base64'));
  console.log(JSON.stringify(report, null, 2));
  ws.close();
} finally {
  if (chrome) { chrome.kill(); await new Promise(resolve => { if (chrome.exitCode !== null) resolve(); else {chrome.once('exit', resolve); setTimeout(resolve, 2000).unref();} }); }
  await rm(dir, {recursive:true, force:true});
}
