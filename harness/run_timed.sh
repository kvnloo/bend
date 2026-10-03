#!/usr/bin/env bash
# Run every timed phase, each in its own exclusive quiet-timed block (<=10 min each).
cd /mnt/zer0models/z0-wt/wiring/bend-perf/harness || exit 1
QT=/mnt/zer0models/github/cua-lanes/bin/quiet-timed
for ph in "$@"; do
  [ -s ../results/$ph.json ] && { echo "skip $ph (exists)"; continue; }
  echo "queue $ph $(date -u +%T)"
  $QT bendperf-$ph timeout 590 python3 bench.py $ph > ../results/work/$ph.log 2>&1
  echo "done $ph rc=$? $(date -u +%T)"
done
