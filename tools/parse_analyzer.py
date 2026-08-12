from pathlib import Path
from collections import Counter, defaultdict
import re
text = Path('analyzer_errors_full.txt').read_text('utf-8-sig')
lines = [l for l in text.splitlines() if 'error -' in l]
print('Total error lines:', len(lines))
# extract symbol names from messages
cats = Counter()
symbols = defaultdict(Counter)
for l in lines:
    m = re.search(r"'([A-Za-z0-9_<>]+)'", l)
    if m:
        sym = m.group(1)
    else:
        # fallback: try to grab a word-like token
        m2 = re.search(r"\b([A-Za-z0-9_]{3,})\b", l)
        sym = m2.group(1) if m2 else 'UNKNOWN'
    # classify heuristics
    low = l.lower()
    if 'provider' in sym or 'provider' in low:
        cats['Missing Riverpod providers'] += 1
        symbols['Missing Riverpod providers'][sym]+=1
    elif sym.endswith('Label') or sym.endswith('Button') or 'label' in low or 'tooltip' in low or 'message' in low or sym.endswith('Title') or sym.endswith('Caption'):
        cats['Missing AppStrings'] += 1
        symbols['Missing AppStrings'][sym]+=1
    elif sym.endswith('Service') or ' service ' in low or 'service(' in low:
        cats['Missing services'] += 1
        symbols['Missing services'][sym]+=1
    elif sym.endswith('Exception') or sym.endswith('Error') or sym.endswith('Model') or sym.endswith('Entry') or sym.endswith('Validation'):
        cats['Missing models/types'] += 1
        symbols['Missing models/types'][sym]+=1
    elif 'import' in low or 'try importing' in low:
        cats['Missing imports'] += 1
        symbols['Missing imports'][sym]+=1
    elif 'constructor' in low or 'has no' in low and 'constructor' in low:
        cats['Constructor signature mismatches'] += 1
        symbols['Constructor signature mismatches'][sym]+=1
    elif 'enum' in low or 'switch' in low or 'non_exhaustive' in low:
        cats['Missing enums / non-exhaustive switches'] += 1
        symbols['Missing enums / non-exhaustive switches'][sym]+=1
    else:
        cats['Other'] += 1
        symbols['Other'][sym]+=1

print('\nCategory counts:')
for k,v in cats.most_common():
    print(f'{k}: {v}')

print('\nTop symbols per category:')
for k in symbols:
    print('\n', k)
    for sym,count in symbols[k].most_common(10):
        print(' ', sym, count)

# Save a simple JSON-like summary
out = []
for k,v in cats.most_common():
    out.append(f"{k}: {v}")
Path('analyzer_summary.txt').write_text('\n'.join(out))
print('\nSummary written to analyzer_summary.txt')
