"""signflip baseline (same RNG as signflip.tmpl.bend). usage: signflip.py {py|np} log2R log2n"""
import sys
M = 0xFFFFFFFF
def h(x):
    a = (x * 2654435761) & M; b = a ^ (a >> 15); c = (b * 2246822519) & M; return c ^ (c >> 13)
def deltas(n):  # signed ints in [-511, 512]
    return [(h(j ^ 2654435769) >> 22) - 511 for j in range(n)]
def run_py(R, n, ln):
    d = deltas(n); t0 = abs(sum(d)); c = 0
    for r in range(R):
        t = 0; base = r << ln
        for j in range(n):
            t += d[j] if (h(base | j) >> 31) == 0 else -d[j]
        c += abs(t) >= t0
    return c
def run_np(R, n, ln, chunk=1 << 12):
    import numpy as np
    def hv(x):
        a = x * np.uint32(2654435761); b = a ^ (a >> np.uint32(15)); c = b * np.uint32(2246822519); return c ^ (c >> np.uint32(13))
    j = np.arange(n, dtype=np.uint32)
    d = (hv(j ^ np.uint32(2654435769)) >> np.uint32(22)).astype(np.int64) - 511
    t0 = abs(int(d.sum())); c = 0
    for lo in range(0, R, chunk):
        r = np.arange(lo, min(R, lo + chunk), dtype=np.uint32)[:, None]
        s = hv((r << np.uint32(ln)) | j[None, :]) >> np.uint32(31)       # 1 = flip sign
        t = np.where(s == 0, d, -d).sum(axis=1)
        c += int((np.abs(t) >= t0).sum())
    return c
mode, lr, ln = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
print((run_py if mode == "py" else run_np)(1 << lr, 1 << ln, ln))
