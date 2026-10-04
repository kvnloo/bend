#!/usr/bin/env bash
# GPU timing block B (signflip): run under quiet-timed; capped with --gpu $CAP; skips if < 2048 MiB free.
set -euo pipefail
S=/mnt/zer0models/z0-wt/wiring/bend-evals; cd $S; R=$S/results/gpu.jsonl; CAP=${CAP:-1GB}
smi(){ nvidia-smi --query-gpu=memory.used,memory.free,utilization.gpu --format=csv,noheader | sed "s/^/$1 /" >> results/gpu-smi.log; }
free=$(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits | head -1)
if [ "$free" -lt 2048 ]; then echo "SKIP: only ${free} MiB free" | tee -a results/gpu-smi.log; exit 75; fi
smi "$(date -u +%FT%TZ) before-B"
b(){ python3 src/bench.py $R "$@"; }
b sf15_gpu 10 -- bin/sf15_gpu --gpu $CAP
b sf20_gpu 10 -- bin/sf20_gpu --gpu $CAP
smi "$(date -u +%FT%TZ) after-B"
