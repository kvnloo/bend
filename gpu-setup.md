# Bend 2 GPU setup on this host (RTX 3080 Ti, CUDA 13.3)

Date: 2026-10-03. Host: i9-10900KF (10C/20T), RTX 3080 Ti 12 GB (sm_86), driver 610.57.04,
Arch/CachyOS `cuda 13.3.1-1` package at `/opt/cuda`, clang 22.1.8.

## TL;DR

- **Bend 2 has a real GPU backend.** A `!` call (`f!(x)`) runs that call and every parallel let
  under it on the GPU. When you build a native binary with `bend f.bend -o f`, Bend compiles the
  emitted C with clang (`-DBEND_CUDA=1 -lcuda -lnvrtc`). The binary then runs `--gpu-build`, which
  uses NVRTC to compile the same C as CUDA into `f.gpu` (a cubin for the local SM). That file
  must stay next to the binary.
- **Root cause of "nvrtc.h missing":** nothing was missing. Bend looks only at
  `$CUDA_HOME/include/nvrtc.h`, and falls back to `/usr/local/cuda` when `CUDA_HOME` is unset
  (`bend2/main.ts` `cli_build`, identical in 2.0.34 and 2.0.35). Arch installs CUDA at `/opt/cuda`
  and has no `/usr/local/cuda`. When the check fails, Bend silently builds CPU-only and `!` runs
  on the CPU pool. **Fix: `export CUDA_HOME=/opt/cuda`.** No downloads, no pip wheels, no
  toolkit install, no sudo.
- At run time `libnvrtc.so.13` and `libcuda.so.1` resolve through the system ld cache
  (`/etc/ld.so.conf.d/cuda.conf` lists `/opt/cuda/lib64`). No `LD_LIBRARY_PATH` is needed.
- CUDA 13 is supported: `comp.ts` branches on `CUDA_VERSION >= 13000` for `cuMemAdvise`. The guide
  says "CUDA 12 at /usr/local/cuda", but 13.3 builds and runs correctly here.
- **2.0.35:** the CUDA path is identical to 2.0.34. The only GPU change is Metal (M1/M2). It is
  installed at `/mnt/zer0models/bend-stack/official-2.0.35/` (from the release tarball,
  sha256 `63039d1a…`; binary sha256 `af967c7c…`).
- **HVM2 / Bend 1 (`bend run-cu`)** was not needed, because Bend 2 has a working GPU path. It is
  a different language and runtime (HigherOrderCO/Bend, Rust plus nvcc); Bend 2 code does not run
  on it.

## Hazard: always cap the GPU heap on this shared card

With no `--gpu` flag, a binary that contains `!` uses the GPU and reserves **managed memory equal
to the whole device** (`corpus_setup`: `dflt = gpu_span()` = `cuDeviceTotalMem`, 12 GB). The GPU is
shared with llama-server (about 8.8 GB) and the Quackles arbiter. **Always pass `--gpu 1GB`** (or
smaller), or `--gpu off`. Our kernels used about 250 MB on the device under `--gpu 512MB`/`1GB`.
Check `nvidia-smi --query-gpu=memory.free --format=csv` first, and skip if under 2 GB.

## Exact commands

```bash
export CUDA_HOME=/opt/cuda                     # THE fix: Bend's default /usr/local/cuda doesn't exist here
export HOME=/mnt/zer0models/z0-wt/wiring/bend-evals/home \
       TMPDIR=/mnt/zer0models/z0-wt/wiring/bend-evals/tmp BEND_NO_TELEMETRY=1
BEND=/mnt/zer0models/bend-stack/official/bend/bin/bend          # 2.0.34 (sha256 7fafb749…)
# BEND=/mnt/zer0models/bend-stack/official-2.0.35/bend/bin/bend # 2.0.35

# build (shared build lock); a program with `!` also writes prog.gpu (NVRTC cubin, sm_86)
flock -s /mnt/zer0models/cua-lane-tmp/locks/quiet-lane.lock "$BEND" prog.bend -o prog
ls prog prog.gpu                               # prog.gpu present = GPU lane built

./prog --gpu 1GB        # run `!` calls on the GPU, heap capped at 1 GB (fails loudly if no usable GPU)
./prog --gpu off        # run `!` calls on the CPU pool (default 20 threads = sysconf ONLN)
./prog --threads 10     # CPU threads
./prog --gpu-build      # rebuild prog.gpu only
```

How to prove a run really used the GPU: with an explicit size (`--gpu 1GB`), a binary that finds
no usable device exits with `--gpu on, but this binary found no usable GPU`. It does not fall
back. We also caught the process in `nvidia-smi --query-compute-apps` (hs32 run: about 250 MiB).

Timed runs: `/mnt/zer0models/github/cua-lanes/bin/quiet-timed <label> <cmd>` (exclusive). Scripts:
`src/block_cpu.sh`, `src/block_cpu_B.sh`, `src/block_gpu.sh`, `src/block_gpu_B.sh`. Each one runs a
command N times after one untimed warm-up and records wall time per process, including process
start (and CUDA init plus cubin load for GPU runs).

## Kernels (all in `src/`, all with bit-exact parity against the Python baselines)

| kernel | what | Bend shape |
|---|---|---|
| `demos/pure_par_sum` | upstream demo, sum of 2^16 numbers | fork tree, `sum!` |
| `demos/pure_par_sort` (`sort16/18/19`) | upstream bitonic sort of 2^k numbers, as a tree | fork tree of mix/flow, `sort!` |
| `hashsum.tmpl.bend` (`hs24…hs32`) | sum of a 32-bit integer hash over 2^k indices mod 2^32 | 2^14 leaves (one per GPU lane), each a flat loop |
| `signflip.tmpl.bend` (`sf15`, `sf20`) | sign-flip permutation test: R = 2^15 or 2^20 resamples × n = 1024 deltas, count of \|T_r\| ≥ \|T_0\| | 2^14 leaves, each a flat loop over resamples × items |

`signflip` has the same shape as the CUA autoresearch evaluator's sign-flip test (20k+ resamples).
Its deltas and signs come from a deterministic hash, so Bend, CPython and NumPy must print the
same count, and they do: R=2^15 → 30986, R=2^20 → 991106. hs30 = 1224355776 (NumPy-verified).
hs32 = 2^31, which is correct by construction: the hash is a bijection on U32, so the sum equals
Σ0..2^32−1 mod 2^32.

Baselines: CPython 3.14.7 (plain loops), NumPy 2.5.2 (vectorized uint32, chunked, single process).
NumPy is the fair comparison.

## Results (quiet-timed, exclusive; median wall seconds per process, including process start)

Ledger receipts (`quiet-lane-ledger.jsonl`): `bend-evals-cpu-A`, `bend-evals-gpu-A`, `bend-evals-cpu-B`,
`bend-evals-gpu-B`, `bend-evals-C`, all rc 0. GPU runs used `--gpu 1GB` with 10.9–11.0 GB free. The
device was 25–42% busy with another tenant just before the GPU rows, so GPU numbers may be
slightly pessimistic. The full table is in `results/TABLE.md`, and raw per-rep times are in
`results/{cpu,gpu}.jsonl`.

**Fixed costs:** CPython start is 0.018 s, `import numpy` 0.064 s, a Bend CPU binary 0.001 s,
and a Bend GPU binary **0.100 s** (CUDA init, cubin load, managed alloc).

| workload | CPython | NumPy | Bend-C 1 thread | Bend-C 20 threads | Bend GPU | best vs NumPy |
|---|---|---|---|---|---|---|
| sign-flip perm test, R=2^15 (≈ evaluator's 20k) × n=1024 | 12.0 | 0.433 | 0.029 | **0.0048** | 0.100 (startup-bound) | **90×** (CPU-C) |
| sign-flip, R=2^20 × 1024 | — | 11.74 | 0.892 | 0.115 | **0.104** | **113×** (GPU) / 102× (CPU-C) |
| sign-flip, R=2^22 × 1024 | — | ≈47 (extrapolated; 1 untimed parity run) | — | 0.451 | **0.146** | GPU 3.1× over CPU-C |
| sign-flip, R=2^24 × 1024 | — | ≈188 (extrapolated) | — | 1.790 | **0.301** | GPU **5.9×** over CPU-C |
| hash-sum 2^24 | 5.15 | 0.166 | — | **0.0021** | 0.098 | 80× |
| hash-sum 2^30 | — | 6.48 | 0.371 | **0.046** | 0.100 | 141× |
| hash-sum 2^32 | — | — | — | 0.180 | **0.136** | GPU 1.3× over CPU-C |
| hash-sum 2^34 | — | — | — | 0.710 | **0.277** | GPU 2.6× over CPU-C |
| bitonic sort demo 2^16 | **0.023** | 0.065 | — | 0.070 | 0.208 | Bend loses |
| bitonic sort demo 2^18 | **0.037** | 0.067 | — | 0.286 | 0.502 | Bend loses (4–14×) |

Every row prints the identical answer in every config (parity checked per rep; see the `stdout`
field). 2.0.35 matches 2.0.34 within noise (hs30 GPU 0.0985 vs 0.1003; `--gpu off` 0.044 vs 0.052).
Running a `!` program with `--gpu off` costs 1–5 ms more than the same program built without `!`.

**Reading it:**
1. **Bend-C on CPU is the big win, and it needs no GPU at all.** On fused integer loops it is 80–140×
   faster than NumPy and about 2500× faster than CPython (hs24 2450×, sf15 2500×). The reason is that clang
   vectorizes Bend's flat tail loops (2.9 G hashes/s on one thread) and the fork tree spreads them
   over 20 threads, while NumPy materializes temporaries and runs one thread. This covers the
   evaluator-sized permutation test (20k–1M resamples).
2. **The GPU pays off only once a job runs ≳0.15 s on CPU-C.** Below that, the 0.1 s CUDA startup
   dominates. At R=2^24 resamples (or 2^34 hashes) the GPU is 2.6–5.9× faster than 20-thread
   CPU-C, and per unit of compute it is roughly 4–9× (subtracting the 0.1 s floor: hs34 4×, sf24 9×). A
   long-running process that issues many bangs would pay the floor once.
3. **Tree/pointer workloads lose.** The upstream bitonic-sort demo (a tree of boxed Nats) is
   4–14× slower than NumPy and CPython. Their sort of an already-reversed array is near O(n), so
   that comparison flatters Python, but the GPU is also slower than CPU-C on it. This matches
   wakamex/bend-bench (bitonic ≥89× slower than CUB).
4. The demo also overflows the checker's stack at 2^20 (`Tree(20n)` expands at check time), so
   2^19 is the maximum size for this demo as written.

## Implication for our evals

Good candidates are sign-flip and permutation tests, bootstrap CIs, and Monte-Carlo, written as
fork tree → flat loop with a counter-based integer RNG, as in `signflip.tmpl.bend`. Also
exhaustive or fuzz enumeration where each case is a cheap integer check (the C1–C13 rule
enumeration). Use Bend-C (CPU) by default, and add `!` plus `--gpu 1GB` only for jobs that
already take ≳0.2 s on CPU-C. Caveats:
- U32/F32 only, with no U64/F64. Bootstrap means on float data need F32 or fixed-point care.
- Data must be passed in, because there is no in-process FFI. The real deltas would come in as
  a Bend array literal or file effect, which these synthetic kernels avoided by generating data
  from a hash.
- Fork depth needs tuning on the device (2^14 leaves worked here; see upstream #828).


## How people actually use Bend (research, 2026-10-03)

- **Upstream demos** (`bendlang/bend` `demos/`, v2.0.34) show the intended shapes:
  `pure_par_sum` and `pure_par_sort` (fork trees, each with a LAWS.bend/PROOF.bend correctness
  proof), `app_slash_boss_3d` (a 120 FPS rasterizer: one `!` per frame, a 4^7-leaf fork tree
  ending in flat loops), `app_ray_tracer_3d`, `pure_hvm5_mini`, `proof_*` (verified kernels), and
  `io_*` (HTTP and TCP servers with C/JS effects). The pattern is a pure parallel kernel, with its
  law proved once, inside a host program.
- **Official benchmarks** (bend2.dev, M4 Max): Game of Life 7.80 s on 1 thread, 0.647 s on
  parallel CPU, 0.063 s on GPU (124×). The lexer goes 2.14 s → 0.198 s on CPU, but takes 1.075 s
  on GPU, so the GPU loses on divergent work. Their advice: measure one-thread, multicore and GPU
  separately on the same input, and check that the outputs agree. That is what we did.
- **Independent suite** (`wakamex/bend-bench`, 22 workload families, Bend 2.0.3/2.0.26 vs
  OpenMP/CUDA): on CPU at 16 threads Bend is 1.3× slower than the same algorithm in C and 14×
  slower than tuned C. On GPU, per unit of work, the median is 5.7× slower than hand CUDA. The
  best cases are Game of Life (1.3×), N-Queens (1.5×) and game search (1.8×); the worst are
  HotSpot (290×), the lexer (200×) and symbolic regression (180×). Bitonic sort is ≥89× slower
  than CUB, and summation 280× slower than CUB. Bend's GPU startup (0.12–0.16 s) is lower than
  conventional CUDA programs' (about 0.18 s). Conclusion: "implementations matter more than
  language choice". Balanced trees ending in flat loops are needed.
- **Upstream issue #828** (fork depth): GPU frame time varies up to 8× with leaf granularity
  (optimum 7 levels), while the CPU stays flat. Fork depth must be tuned per program, on the
  device.
- **Practitioner port** (akitaonrails, 2026-09-19): three Rust CLIs ported to Bend 2. Binaries
  were smaller and idle CPU lower, but "no number here shows Bend faster than Rust on the same
  work". The ports needed 8 hand-written C/JS effects, and Bend has no U64/F64 and no lemma
  library. The fit is narrow: small verified kernels inside larger apps.
- **Older Bend 1 / HVM2** (HigherOrderCO, 2024): bitonic sort was 12.3 s on 1 thread, 0.96 s on
  16 threads (M3 Max), and 0.24 s on an RTX 4090. This is a different runtime; Bend 2 code does
  not run on it.

Takeaway for our evals: Bend wins on **uniform, integer/F32, embarrassingly parallel numeric
loops with no shared mutable data**, such as resampling statistics with a counter-based RNG,
Monte-Carlo, and exhaustive enumeration with cheap per-case checks. It loses on divergent or
branchy per-item work, on tree or pointer data (see the sort rows), on anything that needs
U64/F64, and on small jobs where process start (about 1 ms on CPU, about 100 ms with CUDA)
dominates.

