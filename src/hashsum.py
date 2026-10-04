"""hashsum baseline: sum of hash(i) for i in [0, 2^log2n), mod 2^32. usage: hashsum.py {py|np} log2n"""
import sys
M = 0xFFFFFFFF
def h(x):
    a = (x * 2654435761) & M
    b = a ^ (a >> 15)
    c = (b * 2246822519) & M
    return c ^ (c >> 13)
def run_py(n):
    s = 0
    for i in range(n):
        s += h(i)
    return s & M
def run_np(n, chunk=1 << 22):
    import numpy as np
    s = np.uint64(0)
    for lo in range(0, n, chunk):
        x = np.arange(lo, min(n, lo + chunk), dtype=np.uint32)
        a = x * np.uint32(2654435761)
        b = a ^ (a >> np.uint32(15))
        c = b * np.uint32(2246822519)
        d = c ^ (c >> np.uint32(13))
        s += d.sum(dtype=np.uint64)
    return int(s) & M
mode, k = sys.argv[1], int(sys.argv[2])
print((run_py if mode == "py" else run_np)(1 << k))
