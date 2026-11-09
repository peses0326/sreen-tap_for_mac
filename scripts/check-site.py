#!/usr/bin/env python3
"""Check the buildless landing page without external dependencies."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit

root = Path(__file__).resolve().parent.parent / 'site'
class Check(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()
        self.fragments = []
        self.images = 0
        self.translations = 0
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if 'id' in a:
            assert a['id'] not in self.ids, f'Duplicate id: {a["id"]}'
            self.ids.add(a['id'])
        assert ('data-ko' in a) == ('data-en' in a), f'Incomplete translation: {a}'
        self.translations += int('data-ko' in a)
        if tag == 'img':
            self.images += 1
            assert 'alt' in a and a.get('width') and a.get('height'), 'Image accessibility/layout attributes missing'
        for attribute in ['href', 'src']:
            reference = a.get(attribute, '')
            if reference.startswith('#'):
                if reference != '#': self.fragments.append(reference[1:])
            elif reference and not urlsplit(reference).scheme and not reference.startswith('//'):
                target = root / urlsplit(reference).path
                assert target.is_file(), f'Missing local asset: {reference}'

page = (root / 'index.html').read_text()
check = Check(); check.feed(page)
assert all(fragment in check.ids for fragment in check.fragments), 'Broken section link'
assert {'language', 'try-tab', 'demo-status', 'main'} <= check.ids
assert check.images >= 3 and check.translations > 30
assert 'peses0326' in page and 'MIT License' in page
assert '/Users/' not in page and 'localhost' not in page
print(f'PASS landing page: {check.images} images, {check.translations} bilingual strings, local assets and section links')
