#!/usr/bin/env bash
# CPU timing block: run under quiet-timed (exclusive). Appends to results/cpu.jsonl.
set -euo pipefail
S=/mnt/zer0models/z0-wt/wiring/bend-evals; cd $S; R=$S/results/cpu.jsonl; b(){ python3 src/bench.py $R "$@"; }
b floor_py 5 -- python3 -c pass
b floor_np 5 -- python3 -c 'import numpy'
b floor_bend 10 -- bin/hs_t10_cpu
b hs24_cpython 3 -- python3 src/hashsum.py py 24
b hs24_numpy 5 -- python3 src/hashsum.py np 24
b hs24_bendc 10 -- bin/hs24_cpu
b hs24_bendc_bang_gpuoff 10 -- bin/hs24_gpu --gpu off
b hs26_numpy 5 -- python3 src/hashsum.py np 26
b hs26_bendc 10 -- bin/hs26_cpu
b hs26_bendc_bang_gpuoff 10 -- bin/hs26_gpu --gpu off
b hs30_numpy 3 -- python3 src/hashsum.py np 30
b hs30_bendc 10 -- bin/hs30_cpu
b hs30_bendc_t1 5 -- bin/hs30_cpu --threads 1
b hs30_bendc_bang_gpuoff 10 -- bin/hs30_gpu --gpu off
b hs30_bendc_bang_gpuoff_v2035 10 -- bin/hs30_gpu_35 --gpu off
for k in 16 18; do
  b sort${k}_cpython 5 -- python3 src/sortbase.py py $k
  b sort${k}_numpy 5 -- python3 src/sortbase.py np $k
  b sort${k}_bendc_bang_gpuoff 5 -- bin/sort${k}_gpu --gpu off
done
b sort16_bendc 5 -- bin/sort16_cpu
b sort18_bendc 5 -- bin/sort18_cpu
b sort19_bendc_bang_gpuoff 5 -- bin/sort19_gpu --gpu off
