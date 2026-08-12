from pathlib import Path
text = Path('analyzer_errors_after_appstrings.txt').read_text('utf-8-sig')
lines = [l for l in text.splitlines() if 'error -' in l]
print('Total error lines:', len(lines))
from collections import Counter, defaultdict
import re
cats = Counter(); symbols=defaultdict(Counter)
for l in lines:
    m = re.search(r"'([A-Za-z0-9_<>]+)'", l)
    sym = m.group(1) if m else 'UNKNOWN'
    low = l.lower()
    if 'provider' in sym or 'provider' in low:
        cats['Missing Riverpod providers'] += 1; symbols['Missing Riverpod providers'][sym]+=1
    elif sym.endswith('Label') or sym.endswith('Button') or 'label' in low or 'tooltip' in low or 'message' in low or sym.endswith('Title'):
        cats['Missing AppStrings'] += 1; symbols['Missing AppStrings'][sym]+=1
    elif 'service' in sym.lower() or sym.endswith('Service'):
        cats['Missing services'] += 1; symbols['Missing services'][sym]+=1
    elif 'import' in low or 'try importing' in low:
        cats['Missing imports'] += 1; symbols['Missing imports'][sym]+=1
    elif 'non_exhaustive' in low or 'switch' in low:
        cats['Missing enums / non-exhaustive switches'] += 1; symbols['Missing enums / non-exhaustive switches'][sym]+=1
    else:
        cats['Other'] += 1; symbols['Other'][sym]+=1

print('\nCategory counts:')
for k,v in cats.most_common(): print(f'{k}: {v}')

print('\nTop symbols per category:')
for k in symbols:
    print('\n',k)
    for s,c in symbols[k].most_common(10): print(' ',s,c)
