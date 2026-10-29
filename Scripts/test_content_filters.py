#!/usr/bin/env python3
"""Fixture checks. Install cssselect2 for CSS matching; this is not WebKit compilation."""
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import urlparse
import cssselect2

ROOT = Path(__file__).resolve().parents[1]
RULES = json.loads((ROOT / 'JoeToep/Resources/contentFilters.json').read_text())
assert set(RULES) == {'ads', 'shorts', 'posts', 'premium'}
checks = 0

def blocked(url, page='https://www.youtube.com/watch?v=fixture'):
    return any(rule['action']['type'] == 'block'
               and urlparse(page).hostname in rule['trigger']['if-domain']
               and re.search(rule['trigger']['url-filter'], url)
               for rule in RULES['ads'])

def check(condition, description):
    global checks
    assert condition, description
    checks += 1
    print('PASS', description)

for url in ['https://googleads.g.doubleclick.net/pagead/ads',
            'https://pagead2.googlesyndication.com/pagead/js/ads.js',
            'https://www.googleadservices.com/pagead/conversion/',
            'https://www.youtube.com/api/stats/ads?id=fixture']:
    check(blocked(url), 'ad endpoint blocked: ' + urlparse(url).hostname)

for url in ['https://rr1---sn-fixture.googlevideo.com/videoplayback?id=fixture',
            'https://www.youtube.com/youtubei/v1/player',
            'https://www.youtube.com/youtubei/v1/next',
            'https://accounts.google.com/ServiceLogin',
            'https://www.youtube.com/watch?v=fixture',
            'https://doubleclick.net.example.org/script.js']:
    check(not blocked(url), 'playback/login/lookalike preserved: ' + urlparse(url).hostname)
check(not blocked('https://pagead2.googlesyndication.com/pagead/js/ads.js',
                  'https://accounts.google.com/'), 'rules scoped to YouTube pages')

fixture = ET.fromstring('''<html><body>
  <ytd-ad-slot-renderer id="ad" />
  <ytd-reel-shelf-renderer id="shelf" />
  <ytd-rich-item-renderer id="short"><a href="/shorts/fixture" /></ytd-rich-item-renderer>
  <ytd-backstage-post-thread-renderer id="post" />
  <ytd-video-renderer id="member"><span class="badge-style-type-members-only" /></ytd-video-renderer>
  <ytd-video-renderer id="paid"><span class="badge-style-type-ypc" /></ytd-video-renderer>
  <ytd-video-renderer id="normal"><a href="/watch?v=fixture" /></ytd-video-renderer>
  <div id="movie_player"><video id="playing" class="html5-main-video" /></div>
  <form id="consent" /><button id="skip" class="ytp-ad-skip-button" />
</body></html>''')
root = cssselect2.ElementWrapper.from_html_root(fixture)
expected = {'ads': {'ad'}, 'shorts': {'short', 'shelf'}, 'posts': {'post'}, 'premium': {'member', 'paid'}}
for name, rules in RULES.items():
    selectors = [selector for rule in rules if rule['action']['type'] == 'css-display-none'
                 for selector in cssselect2.compile_selector_list(rule['action']['selector'])]
    hidden = {node.etree_element.get('id') for node in root.iter_subtree()
              if any(selector.test(node) for selector in selectors)}
    check(hidden == expected[name], name + ' hides intended cards and preserves player, consent and skip controls')
strict = json.loads((ROOT / 'JoeToep/Resources/strictAds.json').read_text())
for url, expected in [('https://www.youtube.com/api/stats/atr?x=1', True),
                      ('https://www.youtube.com/pcs/activeview?id=1', True),
                      ('https://www.youtube.com/youtubei/v1/player', False),
                      ('https://www.youtube.com.example.org/pcs/activeview', False)]:
    matched = any(rule['action']['type'] == 'block' and re.search(rule['trigger']['url-filter'], url) for rule in strict)
    check(bool(matched) == expected, 'strict endpoint scope: ' + url)
for rule in strict:
    check(set(rule['trigger']['if-domain']) <= {'youtube.com', 'www.youtube.com', 'm.youtube.com'}, 'strict rules limited to YouTube')
    if rule['action']['type'] == 'css-display-none':
        selectors = cssselect2.compile_selector_list(rule['action']['selector'])
        protected = [node for node in root.iter_subtree() if node.etree_element.get('id') in {'playing','movie_player','consent','skip'}]
        check(not any(selector.test(node) for node in protected for selector in selectors), 'strict cosmetics preserve player and controls')
print(f'PASS {checks} content-filter scenarios (local fixtures; WebKit compile test supplied separately)')
