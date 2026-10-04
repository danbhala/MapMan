#!/usr/bin/env python3
"""Level codes: a whole level in a short text such as "0MM3-C7P1-P7R3-KWTS-4".

This is the reference for scripts/level_code.gd, which the game uses. The two
must agree bit for bit; tests/unit/test_level_code.gd checks the game's codes
against tests/data/level_codes.json, which this script writes.

    python3 godot/tools/level_code.py                 # codes for every level
    python3 godot/tools/level_code.py --fixtures      # rewrite the test fixture
    python3 godot/tools/level_code.py --decode CODE   # print a code's level
    python3 godot/tools/level_code.py --build-table   # see below; refuses to
                                                      # overwrite a shipped table

A code is bits written as Crockford base32 (0-9 A-Z without I L O U), four
characters to a group:

    version 4 | width-1 5 | height-1 4 | options 5 | check 10 | tiles ...

The tiles are arithmetic coded, row by row, each cell guessed from the cells to
its left and above using counts taken from the campaign's levels
(data/level_code_v0.json). That table is part of the format: once a version
ships its table never changes, or every code shared with it reads wrong. New
tile types take the spare symbols at the end of the alphabet (RESERVED), which
old codes never use, so adding tiles needs no new version.

Options: x_hides preset (2 bits), reveal delay preset (2 bits), and whether
any tile starts hidden (1 bit). When it is set, one flag per tile follows the
grid. Level messages and the hand-made reveal order are not part of a code.
"""

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LEVELS = os.path.join(HERE, '..', 'data', 'levels.json')
TABLE = os.path.join(HERE, '..', 'data', 'level_code_v0.json')
FIXTURES = os.path.join(HERE, '..', 'tests', 'data', 'level_codes.json')

VERSION = 0
# Symbol index -> tile character. Spare symbols follow for future tiles.
SYMBOLS = [' ', 'c', 'b', 'd', 'p', 'y', 'r', 'i', '!', 't', 'm', 'w', 'e', 'n', 's',
           'u', 'h', 'l', 'v', 'x', '@', '+', '1', '2', '3', '4', '5', '6', '7', '8', '9']
RESERVED = 12
ALPHABET = len(SYMBOLS) + RESERVED
X_HIDES = [25, 12, 50, 100]
DELAYS = [0.05, 0.1, 0.2, 0.03]
MAX_W, MAX_H = 17, 12
B32 = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'
EDGE = -1
# The model: each count in the table weighs this much, every symbol has a
# floor of 1, and each cell already coded adds ADAPT to its context.
WEIGHT = 8
ADAPT = 8
# A context's counts are scaled down to at most this total when the table is built.
CONTEXT_CAP = 2000
HEADER_BITS = 28

PRECISION = 32
TOP = (1 << PRECISION) - 1
HALF = 1 << (PRECISION - 1)
QUARTER = 1 << (PRECISION - 2)


# --- levels -------------------------------------------------------------------


def canonical(ch):
    """The tile a character plays as: '-' is empty, z and o are plain tiles,
    exits read the same in either case."""
    if ch == '-':
        return ' '
    if ch in 'zo':
        return 'c'
    if ch in 'NSEW':
        return ch.lower()
    return ch


def level_grid(level):
    """(rows, hidden) of a level dictionary, trimmed to the tiles drawn:
    rows as strings of canonical tiles, hidden as a set of (x, y)."""
    rows = [''.join(canonical(c) for c in r) for r in level['rows']]
    loading = level.get('loading') or []
    w = max(len(r) for r in rows)
    rows = [r.ljust(w) for r in rows]
    hidden = set()
    for y, line in enumerate(loading):
        for x, ch in enumerate(line):
            if ch == '*' and x < w and rows[y][x] != ' ':
                hidden.add((x, y))
    top = next(i for i, r in enumerate(rows) if r.strip())
    bottom = max(i for i, r in enumerate(rows) if r.strip())
    left = min(len(r) - len(r.lstrip()) for r in rows if r.strip())
    right = max(len(r.rstrip()) for r in rows)
    rows = [r[left:right] for r in rows[top:bottom + 1]]
    hidden = {(x - left, y - top) for x, y in hidden}
    return rows, hidden


def nearest(values, v):
    return min(range(len(values)), key=lambda i: abs(values[i] - v))


# --- the model ------------------------------------------------------------------


def load_table():
    with open(TABLE) as f:
        return json.load(f)


def build_table(levels):
    counts = {}

    def bump(key, s):
        counts.setdefault(key, [0] * ALPHABET)[s] += 1

    for level in levels:
        rows, _ = level_grid(level)
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                s = SYMBOLS.index(ch)
                left = SYMBOLS.index(row[x - 1]) if x else EDGE
                up = SYMBOLS.index(rows[y - 1][x]) if y else EDGE
                bump('%d,%d' % (left, up), s)
                bump('%d' % left, s)
                bump('', s)
    for key, c in counts.items():
        total = sum(c)
        if total > CONTEXT_CAP:
            counts[key] = [0 if n == 0 else max(1, n * CONTEXT_CAP // total) for n in c]
    return {
        'version': VERSION,
        'note': 'Frozen: level codes of version 0 read with exactly these counts. '
                'Never regenerate or edit (tools/level_code.py).',
        'symbols': ''.join(SYMBOLS),
        'reserved': RESERVED,
        'weight': WEIGHT,
        'adapt': ADAPT,
        'counts': dict(sorted(counts.items())),
    }


class Model:
    def __init__(self, table):
        self.counts = table['counts']
        self.seen = {}

    def freqs(self, left, up):
        key = '%d,%d' % (left, up)
        base = self.counts.get(key) or self.counts.get('%d' % left) or self.counts['']
        seen = self.seen.get(key)
        f = [1 + WEIGHT * n for n in base]
        if seen:
            f = [a + ADAPT * b for a, b in zip(f, seen)]
        return f, key

    def update(self, key, s):
        self.seen.setdefault(key, [0] * ALPHABET)[s] += 1


class FlagModel:
    """Whether each tile starts hidden, guessed from the tile before it."""

    def __init__(self):
        self.f = [[8, 1], [1, 2]]

    def freqs(self, prev):
        return self.f[prev]

    def update(self, prev, bit):
        self.f[prev][bit] += 4


# --- arithmetic coding (Witten, Neal and Cleary, 32-bit) ------------------------------


class Encoder:
    def __init__(self):
        self.low, self.high, self.pending = 0, TOP, 0
        self.bits = []

    def _out(self, bit):
        self.bits.append(bit)
        self.bits.extend([1 - bit] * self.pending)
        self.pending = 0

    def put(self, freqs, s):
        total = sum(freqs)
        lo = sum(freqs[:s])
        hi = lo + freqs[s]
        r = self.high - self.low + 1
        self.high = self.low + r * hi // total - 1
        self.low = self.low + r * lo // total
        while True:
            if self.high < HALF:
                self._out(0)
            elif self.low >= HALF:
                self._out(1)
                self.low -= HALF
                self.high -= HALF
            elif self.low >= QUARTER and self.high < 3 * QUARTER:
                self.pending += 1
                self.low -= QUARTER
                self.high -= QUARTER
            else:
                break
            self.low *= 2
            self.high = self.high * 2 + 1

    def finish(self):
        self.pending += 1
        self._out(0 if self.low < QUARTER else 1)
        return self.bits


class Decoder:
    def __init__(self, bits):
        self.bits, self.at = bits, 0
        self.low, self.high, self.value = 0, TOP, 0
        for _ in range(PRECISION):
            self.value = self.value * 2 + self._next()

    def _next(self):
        bit = self.bits[self.at] if self.at < len(self.bits) else 0
        self.at += 1
        return bit

    def get(self, freqs):
        total = sum(freqs)
        r = self.high - self.low + 1
        target = ((self.value - self.low + 1) * total - 1) // r
        lo, s = 0, 0
        while lo + freqs[s] <= target:
            lo += freqs[s]
            s += 1
        hi = lo + freqs[s]
        self.high = self.low + r * hi // total - 1
        self.low = self.low + r * lo // total
        while True:
            if self.high < HALF:
                pass
            elif self.low >= HALF:
                self.low -= HALF
                self.high -= HALF
                self.value -= HALF
            elif self.low >= QUARTER and self.high < 3 * QUARTER:
                self.low -= QUARTER
                self.high -= QUARTER
                self.value -= QUARTER
            else:
                break
            self.low *= 2
            self.high = self.high * 2 + 1
            self.value = self.value * 2 + self._next()
        return s


# --- codes ------------------------------------------------------------------------------


def check(w, h, options, symbols, flags):
    """10 bits of FNV-1a over everything the code says."""
    v = 0x811C9DC5
    for b in [w, h, options] + symbols + flags:
        v = ((v ^ b) * 0x01000193) & 0xFFFFFFFF
    return (v ^ (v >> 10) ^ (v >> 20)) & 0x3FF


def bits_of(value, n):
    return [(value >> (n - 1 - i)) & 1 for i in range(n)]


def encode(rows, hidden, x_hides=25, delay=0.05, table=None):
    table = table or load_table()
    h, w = len(rows), len(rows[0])
    assert 1 <= w <= MAX_W and 1 <= h <= MAX_H
    symbols = [SYMBOLS.index(ch) for row in rows for ch in row]
    tiles = [(x, y) for y in range(h) for x in range(w) if rows[y][x] != ' ']
    flags = [1 if t in hidden else 0 for t in tiles] if hidden else []
    options = nearest(X_HIDES, x_hides) | nearest(DELAYS, delay) << 2 | (1 << 4 if flags else 0)
    enc = Encoder()
    model = Model(table)
    for y in range(h):
        for x in range(w):
            left = symbols[y * w + x - 1] if x else EDGE
            up = symbols[(y - 1) * w + x] if y else EDGE
            f, key = model.freqs(left, up)
            enc.put(f, symbols[y * w + x])
            model.update(key, symbols[y * w + x])
    flag_model = FlagModel()
    prev = 0
    for bit in flags:
        enc.put(flag_model.freqs(prev), bit)
        flag_model.update(prev, bit)
        prev = bit
    bits = bits_of(VERSION, 4) + bits_of(w - 1, 5) + bits_of(h - 1, 4) + bits_of(options, 5)
    bits += bits_of(check(w, h, options, symbols, flags), 10) + enc.finish()
    bits += [0] * (-len(bits) % 5)
    text = ''.join(B32[int(''.join(map(str, bits[i:i + 5])), 2)] for i in range(0, len(bits), 5))
    # The reader takes missing characters as zeros.
    text = text.rstrip('0')
    return '-'.join(text[i:i + 4] for i in range(0, len(text), 4))


def clean(code):
    code = code.upper().strip()
    if code.startswith('MAPMAN'):
        code = code[6:]
    out = ''
    for ch in code:
        ch = {'O': '0', 'I': '1', 'L': '1'}.get(ch, ch)
        if ch in B32:
            out += ch
        elif ch.isalnum():
            return None
    return out


def decode(code, table=None):
    """{'rows', 'hidden', 'x_hides', 'delay'} or None when the code doesn't read."""
    table = table or load_table()
    text = clean(code)
    if not text or len(text) * 5 < HEADER_BITS:
        return None
    bits = []
    for ch in text:
        bits += bits_of(B32.index(ch), 5)
    def field(start, n):
        return int(''.join(map(str, bits[start:start + n])), 2)
    if field(0, 4) != VERSION:
        return None
    w, h, options, want = field(4, 5) + 1, field(9, 4) + 1, field(13, 5), field(18, 10)
    if w > MAX_W or h > MAX_H:
        return None
    dec = Decoder(bits[HEADER_BITS:])
    model = Model(table)
    symbols = []
    for y in range(h):
        for x in range(w):
            left = symbols[y * w + x - 1] if x else EDGE
            up = symbols[(y - 1) * w + x] if y else EDGE
            f, key = model.freqs(left, up)
            s = dec.get(f)
            model.update(key, s)
            symbols.append(s)
    flags = []
    if options & 16:
        flag_model = FlagModel()
        prev = 0
        for s in symbols:
            if s == 0:
                continue
            bit = dec.get(flag_model.freqs(prev))
            flag_model.update(prev, bit)
            flags.append(bit)
            prev = bit
    if check(w, h, options, symbols, flags) != want or max(symbols) >= len(SYMBOLS):
        return None
    rows = [''.join(SYMBOLS[s] for s in symbols[y * w:(y + 1) * w]) for y in range(h)]
    tiles = [(x, y) for y in range(h) for x in range(w) if rows[y][x] != ' ']
    hidden = {t for t, bit in zip(tiles, flags) if bit}
    return {'rows': rows, 'hidden': hidden, 'x_hides': X_HIDES[options & 3],
            'delay': DELAYS[(options >> 2) & 3]}


def level_code(level, table=None):
    rows, hidden = level_grid(level)
    return encode(rows, hidden, level.get('x_hides', 25), level.get('delay', 0.05), table)


def main(argv):
    with open(LEVELS) as f:
        levels = json.load(f)['levels']
    if '--build-table' in argv:
        if os.path.exists(TABLE) and '--force' not in argv:
            sys.exit('%s is frozen: changing it breaks every shared code.' % TABLE)
        with open(TABLE, 'w') as f:
            json.dump(build_table(levels), f, separators=(',', ':'))
            f.write('\n')
        return
    if '--decode' in argv:
        got = decode(argv[argv.index('--decode') + 1])
        if got is None:
            sys.exit('That code does not read.')
        for y, row in enumerate(got['rows']):
            print(''.join('*' if (x, y) in got['hidden'] else ch for x, ch in enumerate(row)))
        return
    table = load_table()
    codes = []
    for level in levels:
        code = level_code(level, table)
        got = decode(code, table)
        rows, hidden = level_grid(level)
        assert got and got['rows'] == rows and got['hidden'] == hidden, level['number']
        codes.append({'number': level['number'], 'code': code})
    if '--fixtures' in argv:
        os.makedirs(os.path.dirname(FIXTURES), exist_ok=True)
        with open(FIXTURES, 'w') as f:
            json.dump({'codes': codes}, f, indent=1)
            f.write('\n')
        return
    for c in codes:
        print('%3d  %2d  %s' % (c['number'], len(c['code'].replace('-', '')), c['code']))


if __name__ == '__main__':
    main(sys.argv[1:])
