# Bend 2 evals: GPU setup and "where Bend beats Python" (2026-10-03)

Follow-up to kvnloo/bend#4 (AODL gate: wrong workload). Start at **[gpu-setup.md](gpu-setup.md)**.
It covers the root cause of "nvrtc.h missing" (`CUDA_HOME` unset; CUDA is at `/opt/cuda`), the exact
commands, results (CPython vs NumPy vs Bend-C vs Bend GPU), and research on how people use Bend.

- `src/`: kernel templates (`hashsum.tmpl.bend`, `signflip.tmpl.bend`), the generated variants, the
  Python/NumPy baselines, `bench.py`, the timing blocks, and `summarize.py`.
- `results/`: raw per-rep JSONL, `TABLE.md`, nvidia-smi samples, quiet-lane ledger receipts, and
  parity outputs.
- `demos-upstream/`: the bendlang/bend v2.0.34 `pure_par_sum` and `pure_par_sort` demos, as run.
- `provenance.md`: toolchain versions plus sha256 of every compiler and binary (binaries are not
  committed).
