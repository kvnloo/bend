"""Summarize results/{cpu,gpu}.jsonl into results/TABLE.md (median wall s per process; x vs NumPy)."""
import json, os
S = "/mnt/zer0models/z0-wt/wiring/bend-evals/results"
rows = {}
for f in ("cpu.jsonl", "gpu.jsonl"):
    p = os.path.join(S, f)
    if os.path.exists(p):
        for l in open(p):
            r = json.loads(l); rows[r["label"]] = r   # last run of a label wins
groups = [("floor (process start)", ["floor_py", "floor_np", "floor_bend", "gpu_floor_t10"]),
          ("demo par_sum 2^16", ["demo_par_sum"])]
for pre in ("hs24", "hs26", "hs30", "hs32", "hs34", "sf15", "sf20", "sf22", "sf24", "sort16", "sort18", "sort19"):
    groups.append((pre, sorted([k for k in rows if k.startswith(pre + "_")],
                               key=lambda k: -rows[k]["median_s"])))
out = ["| workload | config | median s | min s | reps | x faster than NumPy | output |", "|---|---|---|---|---|---|---|"]
for name, ks in groups:
    base = next((rows[k]["median_s"] for k in ks if k.endswith("_numpy")), None)
    for k in ks:
        if k not in rows: continue
        r = rows[k]; x = "%.1f" % (base / r["median_s"]) if base else ""
        out.append("| %s | %s | %.4f | %.4f | %d | %s | %s |" % (name, k, r["median_s"], r["min_s"], r["reps"], x, ",".join(r["stdout"]) + ("" if r["rc"] == [0] else " rc=%s" % r["rc"])))
open(os.path.join(S, "TABLE.md"), "w").write("\n".join(out) + "\n")
print("\n".join(out))
