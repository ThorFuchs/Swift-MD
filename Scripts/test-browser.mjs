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
  const rendered = execFileSync(cli, ['--strict', '--document', '--highlight', '--katex-node', node, '--katex-module', katex, '--pele-node', node, '--pele-module', pele, '--svg-prefix', 'browser-test'], { input, encoding: 'utf8' });
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
  const expression = `(() => {
    const math = document.querySelector('math'); const svgs = [...document.querySelectorAll('svg')];
    const box = el => { const r = el.getBoundingClientRect(); return {width:r.width,height:r.height}; };
    return { scriptRan: window.__swiftmdPageScriptRan === true,
      math: math && {namespace:math.namespaceURI, box:box(math), text:math.textContent},
      svgs: svgs.map(s => ({namespace:s.namespaceURI, viewBox:s.getAttribute('viewBox'), id:s.id, labelledby:s.getAttribute('aria-labelledby'), describedby:s.getAttribute('aria-describedby'), title:s.querySelector('title')?.textContent, desc:s.querySelector('desc')?.textContent, box:box(s), geometry:s.querySelector('path')?.getBBox().width, text:s.textContent})),
      table:!!document.querySelector('table'), highlighted:!!document.querySelector('.hljs-keyword'),
      scriptsInOutput:${JSON.stringify(rendered.includes('<script'))} };
  })()`;
  const evaluation = await send('Runtime.evaluate', {expression, returnByValue:true});
  if (evaluation.exceptionDetails || !evaluation.result.value) throw Error('DOM inspection failed: ' + JSON.stringify(evaluation));
  const report = evaluation.result.value;
  report.networkRequests = networkRequests;
  if (networkRequests.some(url => url !== pathToFileURL(file).href)) throw Error('Unexpected browser request: ' + JSON.stringify(networkRequests));
  if (report.scriptRan || report.scriptsInOutput || !report.table || !report.highlighted || report.math?.namespace !== 'http://www.w3.org/1998/Math/MathML' || report.math.box.width <= 0 || report.math.box.height <= 0 || report.svgs.length !== 2 || report.svgs.some(s => s.namespace !== 'http://www.w3.org/2000/svg' || !s.viewBox || s.box.width <= 0 || s.box.height <= 0 || !s.geometry || s.labelledby !== s.id + '-title' || s.describedby !== s.id + '-desc' || s.title !== 'Example diagram' || s.desc !== 'Two connected nodes' || !s.text.includes('Start') || !s.text.includes('Finish')) || report.svgs[0].id === report.svgs[1].id) throw Error('Browser assertions failed: ' + JSON.stringify(report));
  const screenshot = await send('Page.captureScreenshot', {format:'png'});
  if (process.env.SWIFTMD_BROWSER_SCREENSHOT) await writeFile(process.env.SWIFTMD_BROWSER_SCREENSHOT, Buffer.from(screenshot.data, 'base64'));
  console.log(JSON.stringify(report, null, 2));
  ws.close();
} finally {
  if (chrome) { chrome.kill(); await new Promise(resolve => { if (chrome.exitCode !== null) resolve(); else {chrome.once('exit', resolve); setTimeout(resolve, 2000).unref();} }); }
  await rm(dir, {recursive:true, force:true});
}
