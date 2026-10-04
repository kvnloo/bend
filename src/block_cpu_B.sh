#!/usr/bin/env bash
# CPU timing block B (signflip permutation test): run under quiet-timed. Appends to results/cpu.jsonl.
set -euo pipefail
S=/mnt/zer0models/z0-wt/wiring/bend-evals; cd $S; R=$S/results/cpu.jsonl; b(){ python3 src/bench.py $R "$@"; }
b sf15_cpython 1 -- python3 src/signflip.py py 15 10
b sf15_numpy 5 -- python3 src/signflip.py np 15 10
b sf15_bendc 10 -- bin/sf15_cpu
b sf15_bendc_t1 5 -- bin/sf15_cpu --threads 1
b sf15_bendc_bang_gpuoff 10 -- bin/sf15_gpu --gpu off
b sf20_numpy 3 -- python3 src/signflip.py np 20 10
b sf20_bendc 10 -- bin/sf20_cpu
b sf20_bendc_t1 3 -- bin/sf20_cpu --threads 1
b sf20_bendc_bang_gpuoff 10 -- bin/sf20_gpu --gpu off
