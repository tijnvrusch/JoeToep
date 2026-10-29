// V26: Boosts (stylesheet + Zap) en de paginalezer van de pagina-assistent. jsdom; WebKit-bridge gesimuleerd.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { JSDOM } = require('jsdom');
const read = name => fs.readFileSync(path.join(__dirname, '../JoeToep/Resources/', name), 'utf8');
const tests = [];
const test = (name, body) => tests.push([name, body]);
const tick = () => new Promise(r => setTimeout(r, 0));

function page(html, { url = 'https://www.youtube.com/watch?v=abcdefghijk', boost } = {}) {
  const dom = new JSDOM(`<!doctype html><html><head><title>Test page - YouTube</title></head><body>${html}</body></html>`,
    { url, runScripts: 'outside-only', pretendToBeVisual: true });
  const w = dom.window;
  const messages = [];
  w.webkit = { messageHandlers: { joeToepLinks: { postMessage: m => messages.push(JSON.parse(JSON.stringify(m))) } } };
  if (boost) w.JOETOEP_BOOST = boost;
  w.eval(read('boosts.js'));
  w.eval(read('pageReader.js'));
  return { w, d: w.document, messages, B: w.JoeToepBoosts, R: w.JoeToepPageReader };
}
const click = (w, el) => el.dispatchEvent(new w.MouseEvent('click', { bubbles: true, cancelable: true }));
const hover = (w, el) => el.dispatchEvent(new w.MouseEvent('mouseover', { bubbles: true }));
// Dezelfde regels als SiteBoost.sanitizedSelector in Swift: anders zou de app de Zap weigeren.
const swiftAccepts = s => s.length > 0 && s.length <= 400 && !/[{}<;@\\\n\r]/.test(s) &&
  [...s].filter(c => c === '"').length % 2 === 0 && [...s].filter(c => c === "'").length % 2 === 0;

// ── Boosts: stylesheet ─────────────────────────────────────────────────────────────────────────
test('boost: apply adds one stylesheet at the end of <head>, disable removes it', () => {
  const { d, B } = page('<p>x</p>');
  const other = d.createElement('style'); d.head.appendChild(other);
  assert.equal(B.apply({ enabled: true, css: 'p { color: red !important; }', site: 'youtube.com' }), true);
  const style = d.getElementById('joetoep-boost-style');
  assert.ok(style); assert.equal(d.head.lastElementChild, style);
  assert.equal(style.textContent, 'p { color: red !important; }');
  assert.equal(B.apply({ enabled: false, css: 'p{}', site: 'youtube.com' }), false);
  assert.equal(d.getElementById('joetoep-boost-style'), null);
});

test('boost: initial config from the prefix applies at document start (before <head> exists)', () => {
  const dom = new JSDOM('<!doctype html><html></html>', { url: 'https://example.com/', runScripts: 'outside-only' });
  const w = dom.window;
  w.document.documentElement.replaceChildren();
  w.JOETOEP_BOOST = { enabled: true, css: 'body { background: black }', site: 'example.com' };
  w.eval(read('boosts.js'));
  const style = w.document.getElementById('joetoep-boost-style');
  assert.ok(style, 'style exists even without <head>');
  assert.equal(style.parentNode, w.document.documentElement);
});

test('boost: with all boosts at document start the script picks this site (www./m. share one key)', () => {
  const all = { 'youtube.com': { enabled: true, css: '#chat { display: none !important; }', site: 'youtube.com' },
                'example.com': { enabled: true, css: 'p { color: red }', site: 'example.com' } };
  for (const [url, expected] of [['https://www.youtube.com/watch?v=1', '#chat'], ['https://m.youtube.com/', '#chat'],
                                 ['https://example.com/a', 'p { color'], ['https://music.youtube.com/', null], ['https://m.com/', null]]) {
    const dom = new JSDOM('<!doctype html><html><head></head><body></body></html>', { url, runScripts: 'outside-only' });
    dom.window.JOETOEP_BOOSTS_ALL = all;
    dom.window.eval(read('boosts.js'));
    const style = dom.window.document.getElementById('joetoep-boost-style');
    if (expected) assert.ok(style && style.textContent.startsWith(expected), url);
    else assert.equal(style, null, url);
  }
  const { B } = page('');
  assert.equal(B.siteKey('WWW.YouTube.com'), 'youtube.com');
  assert.equal(B.siteKey('m.com'), 'm.com');
  assert.equal(B.siteKey('mobile.twitter.com'), 'twitter.com');
});

test('boost: re-installing the script or applying 1,000 times keeps exactly one stylesheet', () => {
  const { w, d, B } = page('<p>x</p>');
  for (let i = 0; i < 1000; i++) B.apply({ enabled: true, css: `p { order: ${i % 7} }`, site: 'youtube.com' });
  w.JOETOEP_BOOST = { enabled: true, css: 'p { order: 1 }', site: 'youtube.com' };
  w.eval(read('boosts.js'));
  assert.equal(d.querySelectorAll('#joetoep-boost-style').length, 1);
  assert.equal(d.getElementById('joetoep-boost-style').textContent, 'p { order: 1 }');
});

test('boost: a site that removes the stylesheet gets it back (watcher)', async () => {
  const { d, B } = page('<p>x</p>');
  B.apply({ enabled: true, css: 'p { color: blue }', site: 'youtube.com' });
  d.getElementById('joetoep-boost-style').remove();
  await tick();
  assert.ok(d.getElementById('joetoep-boost-style'), 'restored after removal');
  d.head.remove();
  await tick();
  assert.ok(d.getElementById('joetoep-boost-style'), 'restored after <head> was replaced');
});

test('boost: garbage config never throws and switches the boost off', () => {
  const { d, B } = page('<p>x</p>');
  for (const value of [null, undefined, 42, 'x', [], { enabled: 'yes', css: 5 }]) assert.equal(B.apply(value), false);
  assert.equal(d.getElementById('joetoep-boost-style'), null);
});

test('boost: no innerHTML anywhere (YouTube enforces Trusted Types)', () => {
  for (const name of ['boosts.js', 'pageReader.js']) {
    const source = read(name);
    assert.ok(!/innerHTML|outerHTML|insertAdjacentHTML|document\.write/.test(source), name);
    assert.ok(!/setInterval\(|requestAnimationFrame\(/.test(source), name + ' has no background timers');
  }
});

// ── Boosts: Zap ────────────────────────────────────────────────────────────────────────────────
test('zap: hover highlights, click hides the element and reports a selector the app accepts', () => {
  const { w, d, B, messages } = page('<div id="secondary"><ytd-item-section-renderer class="style-scope promo"><a href="#">ad</a></ytd-item-section-renderer></div>');
  let siteClicks = 0; d.addEventListener('click', () => siteClicks++);
  assert.equal(B.startZap(), true); assert.equal(B.zapping, true);
  const target = d.querySelector('ytd-item-section-renderer');
  hover(w, target);
  const box = d.querySelector('[data-joetoep="zap"]');
  assert.equal(box.style.display, 'block');
  click(w, target);
  assert.equal(target.style.getPropertyValue('display'), 'none');
  assert.equal(siteClicks, 0, 'the site never sees the zap click');
  assert.equal(messages.length, 1);
  assert.equal(messages[0].event, 'boostZap');
  assert.equal(messages[0].site, 'www.youtube.com');
  const selector = messages[0].selector;
  assert.ok(swiftAccepts(selector), selector);
  assert.ok(!selector.includes('style-scope'), 'volatile classes are skipped: ' + selector);
  assert.equal(d.querySelector(selector), target);
});

test('zap: Esc stops, removes the highlight and tells the app; undo shows the element again', () => {
  const { w, d, B, messages } = page('<section><p class="a">one</p><p class="a">two</p></section>');
  B.startZap();
  const second = d.querySelectorAll('p')[1];
  click(w, second);
  assert.equal(second.style.display, 'none');
  d.dispatchEvent(new w.KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
  assert.equal(B.zapping, false);
  assert.equal(d.querySelector('[data-joetoep="zap"]'), null);
  assert.equal(messages.at(-1).event, 'boostZapEnded');
  assert.equal(B.undoZap(), true);
  assert.equal(second.style.display, '');
  assert.equal(B.undoZap(), false);
});

test('zap: siblings get :nth-of-type, stable ids are used, generated ids are ignored', () => {
  const { d, B } = page('<main id="content"><ul><li class="row">a</li><li class="row">b</li><li class="row">c</li></ul></main><div id="x12345678"><span>q</span></div>');
  const third = d.querySelectorAll('li')[2];
  const s1 = B.selectorFor(third);
  assert.ok(s1.includes(':nth-of-type(3)'), s1);
  assert.equal(d.querySelector(s1), third);
  const s2 = B.selectorFor(d.querySelector('span'));
  assert.ok(!s2.includes('x12345678'), 'auto-generated id not used: ' + s2);
  assert.equal(d.querySelector(s2), d.querySelector('span'));
  assert.equal(B.selectorFor(d.getElementById('content')), '#content');
  assert.equal(B.selectorFor(null), '');
  // Een gewone <p> zonder klassen in een element met een stabiel id → verankerd aan dat id.
  const { d: d2, B: B2 } = page('<div id="a"><p>1</p></div><div id="b"><p>2</p></div>');
  const s3 = B2.selectorFor(d2.querySelector('#b p'));
  assert.ok(s3.startsWith('#b'), s3);
  assert.equal(d2.querySelector(s3), d2.querySelector('#b p'));
});

test('zap: every element of a big generated page gets a valid selector that finds it back', () => {
  let html = '';
  for (let i = 0; i < 40; i++) html += `<div class="card c${i % 3} is-active"><h3 class="title">t${i}</h3><p>${i}</p><span class="meta x${i}"></span></div>`;
  const { d, B } = page(`<div id="grid">${html}</div>`);
  for (const el of d.querySelectorAll('#grid *')) {
    const s = B.selectorFor(el);
    assert.ok(swiftAccepts(s), s);
    assert.equal(d.querySelector(s), el, s);
  }
});

test('zap: starting twice is harmless, clicks on the highlight itself are ignored, stop is idempotent', () => {
  const { w, d, B, messages } = page('<p>x</p>');
  assert.equal(B.startZap(), true); assert.equal(B.startZap(), true);
  assert.equal(d.querySelectorAll('[data-joetoep="zap"]').length, 1);
  click(w, d.body);
  assert.equal(messages.length, 0, 'body/html are never zapped');
  assert.equal(B.stopZap(), true); assert.equal(B.stopZap(), false);
});

// ── Paginalezer ────────────────────────────────────────────────────────────────────────────────
test('reader: article text without menus, scripts, buttons or hidden parts', () => {
  const { R } = page(`<nav>Home Menu</nav><header>Site header</header>
    <article><h1>Balcony solar</h1><p>Panels are small.</p><script>var x = 1;</script><button>Like</button>
    <p hidden>secret</p><div aria-hidden="true">decor</div><p>They pay back in five years.</p></article><footer>© 2026</footer>`,
    { url: 'https://example.com/solar' });
  const result = R.extract(5000);
  assert.equal(result.url, 'https://example.com/solar');
  assert.equal(result.title, 'Test page');
  assert.ok(result.text.includes('Balcony solar'));
  assert.ok(result.text.includes('They pay back in five years.'));
  for (const noise of ['Home Menu', 'Site header', 'var x', 'Like', 'secret', 'decor', '© 2026']) assert.ok(!result.text.includes(noise), noise);
  assert.ok(result.text.split('\n').length >= 3, 'block elements become lines');
});

test('reader: YouTube description under the video, otherwise the meta description', () => {
  const yt = page(`<ytd-watch-flexy><div id="primary"><ytd-player>player</ytd-player><ytd-watch-metadata><h1>Title</h1>
    <div id="description-inline-expander"><yt-attributed-string>In this video we build a robot arm.</yt-attributed-string></div></ytd-watch-metadata></div>
    <ytd-watch-next-secondary-results-renderer>Recommended junk</ytd-watch-next-secondary-results-renderer></ytd-watch-flexy>`);
  const r1 = yt.R.extract();
  assert.equal(r1.description, 'In this video we build a robot arm.');
  assert.ok(!r1.text.includes('Recommended junk'));
  assert.ok(!r1.text.includes('player'));
  const other = page('<main><p>Body text here.</p></main>', { url: 'https://example.com/' });
  const m = other.d.createElement('meta'); m.setAttribute('name', 'description'); m.setAttribute('content', 'Meta summary'); other.d.head.appendChild(m);
  assert.equal(other.R.extract().description, 'Meta summary');
});

test('reader: the character budget is respected on a huge page (and the minimum is 1,000)', () => {
  const huge = '<main>' + '<p>Lorem ipsum dolor sit amet consectetur.</p>'.repeat(20000) + '</main>';
  const { R } = page(huge, { url: 'https://example.com/' });
  const started = Date.now();
  const result = R.extract(5000);
  assert.ok(result.text.length <= 5000, String(result.text.length));
  assert.ok(Date.now() - started < 1500, 'stops walking once the budget is full');
  assert.ok(R.extract(10).text.length <= 1000);
  assert.ok(R.extract(10).text.length > 900);
});

(async () => {
  let failed = 0;
  for (const [name, body] of tests) {
    try { await body(); console.log('PASS', name); }
    catch (error) { failed++; console.error('FAIL', name, '\n', error); }
  }
  if (failed) { console.error(`${failed} of ${tests.length} V26 Arc/Dia scenarios failed`); process.exit(1); }
  console.log(`PASS ${tests.length}/${tests.length} V26 Boosts and page-reader scenarios (jsdom)`);
})();
