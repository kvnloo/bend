#!/usr/bin/env bash
# GPU timing block: run under quiet-timed (exclusive). Every GPU run is capped with --gpu $CAP.
# Refuses to start if the device has < 2048 MiB free. Appends to results/gpu.jsonl.
set -euo pipefail
S=/mnt/zer0models/z0-wt/wiring/bend-evals; cd $S; R=$S/results/gpu.jsonl; CAP=${CAP:-1GB}
smi(){ nvidia-smi --query-gpu=memory.used,memory.free,utilization.gpu --format=csv,noheader | sed "s/^/$1 /" >> results/gpu-smi.log; }
free=$(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits | head -1)
if [ "$free" -lt 2048 ]; then echo "SKIP: only ${free} MiB free" | tee -a results/gpu-smi.log; exit 75; fi
smi "$(date -u +%FT%TZ) before"
b(){ python3 src/bench.py $R "$@"; }
b gpu_floor_t10 10 -- bin/hs_t10_gpu --gpu $CAP
b demo_par_sum 10 -- bin/sum34 --gpu $CAP
b hs24_gpu 10 -- bin/hs24_gpu --gpu $CAP
b hs26_gpu 10 -- bin/hs26_gpu --gpu $CAP
b hs30_gpu 10 -- bin/hs30_gpu --gpu $CAP
b hs30_gpu_v2035 10 -- bin/hs30_gpu_35 --gpu $CAP
b hs32_gpu 10 -- bin/hs32_gpu --gpu $CAP
b hs32_bendc 10 -- bin/hs32_cpu
b hs32_bendc_bang_gpuoff 10 -- bin/hs32_gpu --gpu off
b sort16_gpu 5 -- bin/sort16_gpu --gpu $CAP
b sort18_gpu 5 -- bin/sort18_gpu --gpu $CAP
b sort19_gpu 5 -- bin/sort19_gpu --gpu $CAP
smi "$(date -u +%FT%TZ) after"
