#!/usr/bin/env python3
"""Turn a play log copied from the dev menu into a per-level table.

    python3 godot/tools/playlog_report.py playlog.json
    pbpaste | python3 godot/tools/playlog_report.py      # or paste on stdin

Next to what happened on the phone it shows level_report.py's estimate of
spare seconds on the shortest safe route, so levels that play much harder
than they look on paper stand out. Used by the level-analyst agent.
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import level_report  # noqa: E402


def main(argv):
    text = open(argv[0]).read() if argv else sys.stdin.read()
    log = json.loads(text)
    with open(level_report.LEVELS) as f:
        levels = {lv['number']: lv for lv in json.load(f)['levels']}

    print('Build: {0}'.format(log.get('build', '?')))
    tuning = log.get('tuning', {})
    if tuning:
        print('Tuning: ' + ', '.join('{0}={1}'.format(k, v) for k, v in tuning.items()))
    print()
    head = ['lvl', 'attempts', 'cleared', 'deaths', 'timeouts', 'clear rate',
            'best time left s', 'est. slack s', 'avg moves']
    print(' | '.join(head))
    print(' | '.join('---' for _ in head))
    rows = sorted(log.get('levels', {}).items(), key=lambda kv: int(kv[0]))
    for key, row in rows:
        number = int(key)
        est = level_report.analyse(levels[number]) if number in levels else {}
        attempts = row.get('attempts', 0) or 1
        best = row.get('best_time_left', -1)
        print(' | '.join(str(v) for v in [
            number, row.get('attempts', 0), row.get('wins', 0), row.get('deaths', 0),
            row.get('timeouts', 0), '{0:.0%}'.format(row.get('wins', 0) / attempts),
            best if best >= 0 else '-', est.get('slack_seconds', '-'),
            round(row.get('total_moves', 0) / attempts, 1),
        ]))


if __name__ == '__main__':
    main(sys.argv[1:])
