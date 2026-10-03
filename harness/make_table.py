"""Aggregate results/{single,batch,cold,onetime}.json into results/TABLE.md (median across repeats)."""
from __future__ import annotations

import json
import statistics
from pathlib import Path

R = Path("/mnt/zer0models/z0-wt/wiring/bend-perf/results")


def j(name):
    p = R / f"{name}.json"
    return json.loads(p.read_text()) if p.exists() else None


def med(vals):
    vals = [v for v in vals if v is not None]
    return statistics.median(vals) if vals else None


def g(d, *path):
    for k in path:
        if d is None:
            return None
        d = d.get(k)
    return d


def f(x, nd=0):
    if x is None:
        return "n/a"
    return f"{x:,.{nd}f}"


out = ["# AODL gate decision: CPython vs Bend 2.0.34 (same host, quiet-lane exclusive)", ""]
single, batch, cold, one = j("single"), j("single") and j("batch"), j("cold"), j("onetime")
batch = j("batch")

if single:
    reps = [r["results"] for r in single["repeats"]]
    a50 = med([g(r, "A_python", "kernel_routed", "p50") for r in reps])
    out += ["## Per-decision latency, warm, single request (µs; median of %d repeats)" % len(reps), "",
            f"Host load at start: {single['host']['loadavg']}; busiest: {single['host'].get('top_cpu_now')}", "",
            "| config | kernel-routed e2e p50 | p95 | p99 | x A p50 | all-22,079 p50 | p95 | encode p50 | kernel round-trip p50 | p95 | kernel CPU µs/dec | kernel RSS KB |",
            "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"]
    out.append(f"| A CPython validate() | {f(a50,1)} | {f(med([g(r,'A_python','kernel_routed','p95') for r in reps]),1)} | "
               f"{f(med([g(r,'A_python','kernel_routed','p99') for r in reps]),1)} | 1.0 | "
               f"{f(med([g(r,'A_python','all','p50') for r in reps]),1)} | {f(med([g(r,'A_python','all','p95') for r in reps]),1)} | - | - | - | "
               f"{f(med([g(r,'A_python','cpu_us_per_decision') for r in reps]),1)} (in-proc, all) | - |")
    for name in reps[0]:
        if name == "A_python":
            continue
        p50 = med([g(r, name, "kernel_routed_e2e", "p50") for r in reps])
        mism = sum(g(r, name, "mismatches_vs_reference") or 0 for r in reps)
        out.append(
            f"| {name}{' (MISMATCH %d)' % mism if mism else ''} | {f(p50,1)} | {f(med([g(r,name,'kernel_routed_e2e','p95') for r in reps]),1)} | "
            f"{f(med([g(r,name,'kernel_routed_e2e','p99') for r in reps]),1)} | {f(p50 / a50 if p50 and a50 else None,2)} | "
            f"{f(med([g(r,name,'all_e2e','p50') for r in reps]),1)} | {f(med([g(r,name,'all_e2e','p95') for r in reps]),1)} | "
            f"{f(med([g(r,name,'kernel_routed_encode','p50') for r in reps]),1)} | {f(med([g(r,name,'kernel_roundtrip','p50') for r in reps]),1)} | "
            f"{f(med([g(r,name,'kernel_roundtrip','p95') for r in reps]),1)} | {f(med([g(r,name,'kernel_cpu_us_per_kernel_decision') for r in reps]),1)} | "
            f"{f(med([g(r,name,'kernel_peak_rss_kb') for r in reps]))} |")
    out.append("")

def batch_table(batch, title):
    global out
    reps = batch["repeats"]
    out += [f"## Batched throughput, {title} (median of %d repeats)" % len(reps), "",
            f"Host load at start: {batch['host']['loadavg']}; busiest: {batch['host'].get('top_cpu_now')}. "
            f"Bend rows: kernel only, {batch['n_kernel_lines']:,} pre-encoded request lines in one stdin; "
            "Python rows: validate() over the same 10,019 kernel-routed documents.", "",
            "| config | wall µs/decision | decisions/s | CPU µs/decision | peak RSS KB | parity |",
            "| --- | --- | --- | --- | --- | --- |"]
    for name in reps[0]:
        rows = [r[name] for r in reps]
        par_ok = all(x.get("identical_to_reference", True) for x in rows)
        out.append(f"| {name} | {f(med([x.get('wall_us_per_decision') for x in rows]),1)} | "
                   f"{f(med([x.get('decisions_per_s') for x in rows]))} | {f(med([x.get('cpu_us_per_decision') for x in rows]),1)} | "
                   f"{f(med([x.get('peak_rss_kb') for x in rows]))} | {'ok' if par_ok else 'MISMATCH'} |")
    out += ["", f"Native process start (empty stdin): p50 {f(g(batch,'native_process_start_empty_stdin_us','p50'))} µs", ""]


if batch:
    batch_table(batch, "rerun")
run1 = j("batch_run1_noisy")
if run1:
    batch_table(run1, "run 1")

mem = (j("memory") or {}).get("python_validator_process") or [{"vmhwm_kb_bare_interpreter": None, "vmhwm_kb_after_import_and_validate": None}]
if cold:
    out += [f"Cold block host load at start: {cold['host']['loadavg']} (above the PREREG 3.0 noise threshold; not rerun, see README)", ""]
    a, b = cold["A_python_cold"], cold["B_bend_cold_persistent"]
    out += ["## Cold (fresh process, first decision; p50 of 10 µs)", "",
            "| path | p50 | p95 |", "| --- | --- | --- |",
            f"| A: python3 process total (start + import + 2 validates) | {f(a['process_total_us']['p50'])} | {f(a['process_total_us']['p95'])} |",
            f"| A: import aodl_contract | {f(a['import_us']['p50'])} | {f(a['import_us']['p95'])} |",
            f"| A: first validate() | {f(a['first_validate_us']['p50'],1)} | {f(a['first_validate_us']['p95'],1)} |",
            f"| A: second validate() | {f(a['second_validate_us']['p50'],1)} | {f(a['second_validate_us']['p95'],1)} |",
            f"| A: python validator process VmHWM KB (bare interpreter -> after import+validate; results/memory.json) | {f(mem[0]['vmhwm_kb_bare_interpreter'])} -> {f(mem[0]['vmhwm_kb_after_import_and_validate'])} | |",
            f"| B: spawn gate + first reply | {f(b['spawn_plus_first_reply_us']['p50'])} | {f(b['spawn_plus_first_reply_us']['p95'])} |",
            f"| B: second reply, same process | {f(b['second_reply_us']['p50'],1)} | {f(b['second_reply_us']['p95'],1)} |",
            f"| B: gate process peak RSS KB | {f(b['peak_rss_kb']['p50'])} | |",
            f"| B-argv: one process per decision (200 docs) | {f(cold['B_argv_process_per_decision_us']['p50'])} | {f(cold['B_argv_process_per_decision_us']['p95'])} |",
            f"", f"Doc: {cold['doc']}; argv mismatches vs reference: {cold['B_argv_mismatches']}", ""]

if one:
    def ws(x):
        return [y["wall_s"] for y in (x if isinstance(x, list) else [x])]
    out += ["## One-time costs (s)", "", "| step | wall s (each run) | rc |", "| --- | --- | --- |"]
    for k in ("bend_build_native", "bend_emit_c", "clang_O3_only", "check_only_main", "proof_check",
              "proof_verdict_cold_kernel", "proof_verdict_warm_kernel"):
        if k in one:
            v = one[k]
            rcs = sorted({y["rc"] for y in (v if isinstance(v, list) else [v])})
            out.append(f"| {k} | {', '.join(f'{w:.2f}' for w in ws(v))} | {rcs} |")
    out.append("")

(R / "TABLE.md").write_text("\n".join(out) + "\n")
print("\n".join(out))
