Proposed text corrections (not applied) for
/mnt/zer0models/github/cua-lanes/artifacts/bend-stack/SYNTHESIS.md

Line 135, replace
  "Bend gate 4-25x slower, not for the hot path."
with
  "Bend gate ~5.2-5.7x slower per decision than in-process CPython on the same host
   (2.5x p50 over all 22,079 cases; ~22x with a process per decision). Not a
   misconfiguration: native -O3 build already; threads/-march/batching/2.0.35 move it <=10%.
   Not for the hot path. (wiring/bend-perf REPORT.md)"

Line 119, append after "warm p50 140 ms, p90 152 ms.":
  " The 22.6 s bootstrap recurs once per Hermes session because session_kernel.py uses a
   fresh HOME; patch 0001 persists the hash-pinned kernel per profile."
