#!/usr/bin/env bash
# Block C (scale-up, CPU-C vs GPU): run under quiet-timed; GPU capped with --gpu $CAP; GPU rows skip if < 2048 MiB free.
set -euo pipefail
S=/mnt/zer0models/z0-wt/wiring/bend-evals; cd $S; CAP=${CAP:-1GB}
smi(){ nvidia-smi --query-gpu=memory.used,memory.free,utilization.gpu --format=csv,noheader | sed "s/^/$1 /" >> results/gpu-smi.log; }
bc(){ python3 src/bench.py results/cpu.jsonl "$@"; }; bg(){ python3 src/bench.py results/gpu.jsonl "$@"; }
bc sf22_bendc 5 -- bin/sf22_cpu
bc sf24_bendc 3 -- bin/sf24_cpu
bc hs34_bendc 5 -- bin/hs34_cpu
free=$(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits | head -1)
if [ "$free" -lt 2048 ]; then echo "SKIP GPU: only ${free} MiB free" | tee -a results/gpu-smi.log; exit 75; fi
smi "$(date -u +%FT%TZ) before-C"
bg sf22_gpu 5 -- bin/sf22_gpu --gpu $CAP
bg sf24_gpu 5 -- bin/sf24_gpu --gpu $CAP
bg hs34_gpu 5 -- bin/hs34_gpu --gpu $CAP
smi "$(date -u +%FT%TZ) after-C"
