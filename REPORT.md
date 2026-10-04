# Bend slowdown triage: was "4-25x slower than Python" a misconfiguration?

## Verdict
The slowdown is real. Bend is not misconfigured, and Bend is not slowing down any live path.

- **Where the claim came from.** "4-25x" is from the AODL gate experiment (z0intelligence exp/bend-aodl-gate @a0e95785, bend/aodl_gate/README.md). It was measured on a different machine (i7-4870HQ) while pytest ran alongside it. It mixed three things: a warm pipe, one process per decision, and spawn cost. No row in its table gives 4x.
- **The setup was already the fast path.** The gate already used Bend's documented fast path: `bend main.bend -o gate` emits C, clang compiles it with -O3, and the native binary stays running as one process. The slow modes (the checker/interpreter, or `bend file.bend` running JS on one core) were not used.
- **Re-measured on this host:** 5.2-5.7x slower per decision than in-process CPython (pre-registered, exclusive quiet lane, parity-checked). These knobs each moved the result by 10% or less: thread count, -march=native, batching, dropping the adapter thread, and Bend 2.0.35. An independent audit reproduced it within 3%.
- **Why "Bend should be much faster" doesn't apply.** Bend is fast at parallel reduction over large, balanced work. One gate decision is about 40 µs of branchy, serial validation over a small JSON document. Bend 2 also has no JSON reader and can't be called in-process, so Python encodes every document first. That step alone (49.5 µs) costs more than Python's whole validate() (40.9 µs).
- **The one real, fixable configuration cost is not in the gate.** bend-native gives each Hermes session a fresh HOME. Bend caches its BendTT kernel under $HOME/.bend/bendtt, so every session rebuilds it: 22.6-27.8 s, against 0.40 s warm. Patch 0001 fixes this.
- **"Warm p50 140 ms" is bend_verify.** That is proof checking with `--verdict`, not running a program. Python has no equivalent, so there is nothing to compare it with.

## Root cause
| claim | what it measured | cause | configurable? |
|---|---|---|---|
| "4-25x slower" | Native -O3 binary over a pipe vs an in-process Python call, on another host under load | Python encode before Bend (49.5 µs), plus about 154 µs of kernel CPU per decision. Only about 27 µs of that is the byte scan; about 82% is the closure parser and list-based rules. The pipe adds about 7 µs. One small decision cannot use parallelism. | No. Workload shape plus kernel code. |
| "warm 140 ms" | `bend PROOF.bend --verdict` as a subprocess per call, on the toy fixture | Bun start-up, the check and the kernel recheck; about 29 ms of it is plugin overhead | Not a slowdown against Python. |
| "bootstrap 22.6 s" | First bend_verify in each Hermes session | session_kernel.py:39-42 sets a fresh HOME per session, so Bend misses its kernel cache and rebuilds it | Yes. Patch 0001. |

Two earlier explanations were wrong and are corrected here:
- **The cost split.** The gate README and docs-audit M3 blamed mostly the per-byte scan. The audit's scan-only control shows the scan is about 18% of kernel CPU.
- **The "2-3x" smoke figure.** The bench_modes.py run measured fail-closed DENY 0 replies, so it measured nothing real.

## Corrected numbers
These are in the table field. Sources: /mnt/zer0models/z0-wt/wiring/bend-perf/results/TABLE.md and AUDIT.md. Every configuration's replies were byte-identical to the parity reference, and that reference had 0 false allows against validate().

## Fixes
None of these were applied to anyone else's branch.

1. **patches/0001-bend-native-persist-bendtt-kernel-per-profile.patch** (bend-native @e85e65e; `git apply --check` is clean)
   - session_kernel.py: a kernel is cached per profile and per Bend runtime identity. It is reused only if the slot is owned by the user, has mode 0700, and the kernel still hashes to the recorded sha256. Reuse goes through the existing session-pinned path (BENDTT plus expected sha), and new kernels are published atomically.
   - service.py: the cache root is <HERMES_HOME>/cache/bend-kernel. HERMES_BEND_KERNEL_CACHE=0 disables it.
   - A new 3-test unit file fails on the original and passes with the patch.
   - With real Bend 2.0.34 and Lean 4.34.0, the first session reported session-bootstrap and the second reported session-pinned, both pass.
   - Owner decision: whether the cache should be shared across profiles (~/.cache) instead.
2. **patches/0002-aodl-gate-readme-corrected-latency.patch** (gate README): corrects the ratio, the table and the cost split.
3. **patches/0003-synthesis-corrections.md:** replacement text for SYNTHESIS.md lines 119 and 135.
4. **No flag changes for the gate.** GPU is unavailable (nvrtc.h is missing) and wouldn't help this work anyway. HVM/Bend-1 modes don't exist in Bend 2.
5. **If Bend for AODL is pursued (program work, owner call):**
   - Rewrite the parser and rules with arrays instead of List and without the closure monad first; they are about 82% of kernel CPU.
   - Move shape checking and interning into aodl_contract.to_core().
   - Only offline batch/CI fuzzing with a balanced fork-join kernel is worth trying, against a bar of about 111k decisions/s from Python on 10 processes.

## Artifacts
All paths are under /mnt/zer0models/z0-wt/wiring/bend-perf/:
- PREREG.md, results/, harness/, kernels/par/
- trace.md, docs-audit.md, AUDIT.md
- patches/ (0001, 0002, 0003)
- patches/work/: the a/ and b/ sources, the unit test, and e2e/run.py

## Table

Warm, single request. i9-10900KF, Bend 2.0.34, 10,019 kernel-routed docs, median of 3, exclusive quiet lane (clean block, load 2.34), µs.

| config | p50 | p95 | x Python p50 |
|---|---|---|---|
| A CPython validate() in-process | 40.9 | 95.8 | 1.00 |
| host encode only (Bend path pays this) | 49.5 | | 1.21 |
| B original gate (adapter, --threads 1) | 232.6 | 584.7 | 5.69 |
| C1 plain pipe | 210.7 | 559.2 | 5.16 |
| C2 default 20 threads | 212.2 | 561.4 | 5.19 |
| C3 -march=native | 211.9 | 566.6 | 5.19 |
| C5 fork-join kernel, single request | 212.4 | 560.2 | 5.20 |
| audit re-run of C1 | 214.6 / 217.5 | | 5.26 / 5.30 |
| Bend 2.0.35, single request (audit) | 214.5 | | ~5.2 |
| kernel CPU per decision (B) | ~154 | | 3.8 |
| of which input scan only (audit control) | ~27 | | |
| B over all 22,079 cases | 101.4 | | 2.5 (4.9 at p95) |
| B-argv, one process per decision | 898 | 1,498 | ~22 |

Batch throughput, kernel only (noisy blocks, load 5.5-11), decisions/s:

| config | decisions/s |
|---|---|
| CPython, 1 core | ~20-21k |
| CPython, 10 processes | ~111k |
| Bend serial | ~6.0-6.6k |
| Bend fork-join, 20 threads | ~7.8-12.4k (audit ~13k) |
| Bend JS run mode | ~2.2-2.4k |

Cold and one-time costs (noisy blocks):

| item | value |
|---|---|
| Bend spawn + first reply | 0.66 ms (2.9 MB) |
| Python new process + import + first validate | 32.5 ms |
| --verdict, cold kernel | 27.8 s |
| --verdict, warm kernel | 0.40-0.44 s |
| bend -o build | 4.0-5.6 s |
