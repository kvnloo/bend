# Is Bend misconfigured for the AODL gate? Same-host benchmark results (2026-10-03)

Pre-registration: `../PREREG.md` (commit 5844252, before any timed run). Raw data: `single.json`,
`batch.json` (rerun), `batch_run1_noisy.json`, `cold.json`, `onetime.json`, `memory.json`,
`parity.json`. Table: `TABLE.md` (built by `../harness/make_table.py`). Every timed block ran via
`quiet-timed` (exclusive); see the ledger entries `bendperf-*` in
`/mnt/zer0models/cua-lane-tmp/locks/quiet-lane-ledger.jsonl`.

## Answer

**No, it isn't misconfigured.** The gate already uses Bend's documented fast path: a native C binary
built with clang -O3, kept running as one long-lived process. Every other documented setting I tried was
no faster, or only marginally faster. Python is faster here for two reasons, and neither is a flag:

1. **The compiled Bend kernel spends about 154 µs of its own CPU per decision.** CPython's entire
   `validate()` takes about 41 µs (p50). The kernel walks a linked list one byte at a time and parses
   with closures, so it does about 3.8x more work than Python on every decision, even after compilation.
   IPC is not the problem: the round trip (161 µs) is only about 7 µs more than the kernel's own CPU time.
2. **Before the kernel can run, Python must shape-check and encode the JSON.** That step alone costs
   49.5 µs p50, which is 1.2x the whole Python validation. So even a kernel that took zero time would
   lose to Python.

Bend's parallel runtime does work after a small program change: about 2.1-2.4x at 10 threads and 2.5-3.2x at 20,
with byte-identical verdicts. Even so, its best throughput (about 12k decisions/s on 20 threads) is
below a single Python core (about 21k/s) and about 9x below Python on 10 processes (about 111k/s).

## Parity (before timing)

Corpus: the frozen 22,079-case corpus (seed 48, 20k fuzz), sha256 `0e415e9e…93fe0d`. The reference
configuration B reproduces the README result exactly: 0 false allows, 1 false deny (hotl-0.1, not
modelled), and 0 issue-code disagreements across the 9,519 kernel-routed cases that raise no exception.
Every other Bend configuration returned byte-identical replies for all 10,019 kernel-routed requests.
That covers batch t1, default threads and march=native, the parallel kernel at t1, t10 and t20, the pipe
variants, and the JS run mode. Every timed run checked its replies again.

## Per-decision latency, warm, one request at a time (the boundary that matters)

Block load at start 2.34 (clean). µs, median of 3 repeats; the "x A" column is relative to A on the
same 10,019 kernel-routed documents.

| config | e2e p50 | p95 | p99 | x A (p50) | encode p50 | kernel round trip p50 | kernel CPU/decision | kernel RSS |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **A** CPython `validate()` in-process | **40.9** | 95.8 | 128.6 | 1.0 | - | - | - | (in-process; validator process 17.2 MB) |
| **B** as measured originally (adapter, --threads 1) | 232.6 | 584.7 | 626.0 | **5.69** | 49.5 | 180.6 | 153.7 | 6.8 MB |
| C1 plain pipe (no thread per call) | 210.7 | 559.2 | 617.7 | 5.16 | 48.4 | 161.4 | 154.7 | 8.8 MB |
| C2 default threads (20) | 212.2 | 561.4 | 602.0 | 5.19 | 48.8 | 162.4 | 153.7 | 8.9 MB |
| C3 clang -O3 -march=native | 211.9 | 566.6 | 610.2 | 5.19 | 48.2 | 162.2 | 155.7 | 7.2 MB |
| C5 parallel kernel, one request | 212.4 | 560.2 | 614.1 | 5.20 | 49.4 | 162.3 | 152.7 | 8.8 MB |

Over all 22,079 cases (55% are rejected by the Python host shape check before Bend runs): A p50 39.9
µs, B 101.4 µs (2.5x), p95 94.7 vs 465.1 µs (4.9x). Process per decision (argv, README row) costs p50
898 µs (22x A). Those rows bracket the README's "4-25x". The README's latency table has no row near
4x; on this host, about 5x matches the all-cases p95 and the kernel-routed p99.

## Batched throughput (kernel only; Python over the same 10,019 documents)

Both batch blocks were noisy. Run 1 started at load 5.49 (kswapd, git); the PREREG rerun started at
load 11.1 (Discord, unrelated python3.10 processes). These are processes outside the lock, so the
exclusive lock could not exclude them. The serial rows agree between the two runs; the parallel rows are
noisier. Format: run 1 / rerun.

| config | wall µs/decision | decisions/s | CPU µs/decision | peak RSS |
| --- | --- | --- | --- | --- |
| A CPython, 1 core | 47.1 / 50.2 | 21,248 / 19,912 | 47 / 50 | - |
| A-mp10 (10 fork workers, gc.freeze) | invalid in run 1 (CoW bug, fixed) / **9.0** | - / **110,743** | - | - |
| host encode alone (the Bend path must pay this) | 50.6 / 54.2 | 19,746 / 18,435 | - | - |
| C4 batch, serial kernel, t1 | 155.8 / 167.4 | 6,416 / 5,975 | 154 / 167 | 33 MB |
| C4 batch, default threads | 151.5 / 161.9 | 6,601 / 6,178 | 151 / 161 | 31 MB |
| C4 batch, march=native | 172.9 / 169.3 | 5,785 / 5,906 | 160 / 168 | 33 MB |
| C5 parallel kernel t1 | 261.7 / 316.3 | 3,821 / 3,161 | 261 / 314 | 33 MB |
| C5 t4 | 135.0 / 184.6 | 7,407 / 5,418 | 245 / 315 | 37 MB |
| C5 t10 | 107.7 / 148.1 | 9,284 / 6,752 | 273 / 335 | 43 MB |
| C5 t20 (default) | **80.6** / 128.1 | **12,409** / 7,805 | 289 / 347 | 52 MB |
| D `bend main.bend` (JS run mode, the slow default) | 415.9 / 460.6 | 2,404 / 2,171 | 650 / 728 | 559 MB |

Run 1 peak RSS values were invalid: `wait4` maxrss is inherited from the Python parent. This was fixed
for the rerun, which polls the child's VmHWM. The RSS column above comes from the rerun.

## Cold and one-time costs (blocks at load about 11, flagged noisy, not rerun)

| item | value |
| --- | --- |
| Python: new interpreter + import + first validate | 32.5 ms p50 (import 5.4 ms; first validate 84 µs; second 53 µs) |
| Bend: spawn the gate + first reply | 0.66 ms p50 (second reply 131 µs); process 2.9 MB |
| `bend main.bend -o gate` (emit C + clang -O3) | 4.0-5.6 s (emit C 0.86 s, clang 3.07 s) |
| `--check-only` main.bend / `bend PROOF.bend` (all laws) | 0.15 s / 0.17 s |
| `bend PROOF.bend --verdict`, cold BendTT kernel (new HOME) | **27.8 s** (Lean build of the kernel) |
| `--verdict`, warm kernel cache | 0.40-0.44 s |

Bend's only clear win is cold start, where the native binary starts about 50x faster than CPython. But
the validator runs inside the controller process, so the gate never pays that cost. The one real
configuration problem in the stack is **not** in the gate. It is bend-native's per-session `HOME`,
which makes every Hermes session pay the cold `--verdict` kernel build (27.8 s here, 22.6 s in
SYNTHESIS §6) instead of the 0.4 s warm path (`trace.md`, `docs-audit.md` M1).

## Prediction scorecard (PREREG)

| # | prediction | result |
| --- | --- | --- |
| P1 | no C-config reaches A at p50 | **held**: best 5.16x (C1) |
| P2 | encode ≥ 0.7x A | **held**: 1.21x |
| P3 | C1 saves ≤ 40 µs | **held**: 21.9 µs |
| P4 | default threads no faster on the serial kernel | **held**: within 3% |
| P5 | march=native within ±5% | held on CPU (+4%/+1%); run 1 wall +11% (noisy) |
| P6 | batching lowers kernel µs/decision; CPU stays above A | **partly failed**: batching gave about 0-3% (IPC is not the cost); CPU 3.3x A held |
| P7 | parallel ≥ 3x at t10; A-mp10 the fair comparison | **failed** on scaling: t10 2.1-2.4x (t20 2.5-3.2x). A-mp10 beats C5-t10 by about 16x |
| P8 | JS mode ≥ 3x slower than native batch | **failed narrowly**: 2.7x |
| P9 | build ≈ 4 s; cold verdict ≥ 15 s; warm ≤ 3 s | **held** |

Decision rule outcome: no configuration-only change (C1-C4) brings Bend to A's per-decision cost or
improves B by 2x or more. The best was 1.10x (C1). So the verdict is **not misconfigured**.

## What would actually make Bend competitive here (not measured; these are program changes, not config)

- Replace the decimal-text, linked-list byte scanner and the closure-based parser with an array or
  binary token format. That attacks the 154 µs of kernel CPU.
- Even then, the 49.5 µs Python encode puts a floor above A's 41 µs at this boundary. Bend can only win
  if it reads the source document itself, or if the per-request boundary goes away (large batches with
  parallel encode). On throughput, Python multiprocessing is already at about 111k decisions/s.
- Keep `validate()` on the hot path, as the gate README already recommends. Use the Bend kernel for
  proven-spec checks and CI differential fuzzing.

## Caveats

- Only the `single` block, the primary metric, ran on a quiet host. Batch, cold and one-time all
  started above the PREREG load threshold (5.5-11) because of processes outside the lock lanes.
  Batch got its one PREREG rerun, which was also noisy. Cold and one-time were not rerun.
- A-mp10 in run 1 was a harness defect (CoW through GC in forked workers; inner runs ranged 8-116 µs).
  It was fixed with `gc.freeze()` before the rerun, in commit 4450e01.
- The prior `bench_modes.py` (docs-audit) sent `bytes` tokens through `BendGate.raw`. The kernel
  therefore read `b'1'` and answered `DENY 0` immediately, so its unofficial "2-3x" adapter smoke
  number measured the fail-closed fast path, not a real decision. This harness decodes the tokens and
  checks every reply against the reference.
- Not measured: GPU (`nvrtc.h` absent, and the gate has no `!` calls), and Bend 2.0.35 (not installed).
