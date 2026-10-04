"""sort baseline matching demos/pure_par_sort: sort 2^k descending numbers, check ascending. usage: sortbase.py {py|np} k"""
import sys
mode, k = sys.argv[1], int(sys.argv[2]); n = 1 << k
if mode == "py":
    s = sorted(range(n - 1, -1, -1)); ok = s == list(range(n))
else:
    import numpy as np
    s = np.sort(np.arange(n - 1, -1, -1, dtype=np.uint32)); ok = bool((s == np.arange(n, dtype=np.uint32)).all())
print("sorted" if ok else "unsorted")
