"""bench.py <out.jsonl> <label> <reps> -- <cmd...>: run cmd reps times (after 1 untimed warmup),
record wall seconds and stdout of each run; append one JSON line. Used under quiet-timed."""
import json, subprocess, sys, time, statistics
out, label, reps = sys.argv[1], sys.argv[2], int(sys.argv[3])
cmd = sys.argv[sys.argv.index("--") + 1:]
subprocess.run(cmd, capture_output=True)  # warmup (page cache, .gpu load)
walls, outs, rcs = [], [], []
for _ in range(reps):
    t = time.perf_counter()
    p = subprocess.run(cmd, capture_output=True, text=True)
    walls.append(time.perf_counter() - t)
    outs.append(p.stdout.strip()); rcs.append(p.returncode)
rec = {"label": label, "cmd": cmd, "reps": reps, "wall_s": walls,
       "median_s": statistics.median(walls), "min_s": min(walls),
       "stdout": sorted(set(outs)), "rc": sorted(set(rcs)),
       "stderr_tail": p.stderr[-400:], "utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
open(out, "a").write(json.dumps(rec) + "\n")
print(label, "median %.4fs min %.4fs" % (rec["median_s"], rec["min_s"]), rec["stdout"], rec["rc"])
