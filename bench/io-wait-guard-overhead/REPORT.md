# io_run wait-guard overhead (emitted-JS lane)

Question: the consolidated wait guards (`muse/guards-consolidated-clamp-repair`)
add per-wait validation to `RUNTIME_MAIN`'s `io_run` in `bend2/comp.ts` — the
read arm does `Number(fd)` plus an integer/nonnegative check, the time arm
does `Number(ms)` plus `isFinite`. Does this measurably slow the wait path?

## Method

- `wait_bench.bend`: 20000 sequential `IO.sleep(0)` waits. Every iteration
  takes the `{time}` wait path, through the added `Number`/`isFinite` checks.
- Trees compared: fork main `6018e28e` (unguarded `RUNTIME_MAIN`) vs fork
  main with the repair branch's `bend2/comp.ts` (guarded). `comp.ts` is the
  only file of that branch that affects the JS runtime for this program
  (its other changes are effs twins, docs, and test pins).
- Lane: emitted JS — `bun bend2/main.ts wait_bench.bend -o out.js`, then time
  `bun out.js` — so the checker and compile stay out of the measured loop.
  `BEND_NO_TELEMETRY=1`. Binaries alternated per rep; medians reported.
- Pilot: the interp lane (`bun bend2/main.ts wait_bench.bend` directly) was
  tried first and abandoned: ~750ms of per-run checker fixed cost plus box
  noise swamped any per-wait signal.

## Results

| waits | reps | base median | guarded median | delta | per wait |
|------:|-----:|------------:|---------------:|------:|---------:|
| 4000  | 11   | 139.2ms     | 174.2ms        | +35.0ms | +8.75us |
| 20000 | 9    | 266.5ms     | 249.1ms        | −17.4ms | −0.87us |

The 4000-wait delta did not scale with N (run spreads overlapped heavily:
base 87–450ms, guarded 69–628ms) — it was noise. At 20000 waits the guarded
tree is, if anything, marginally faster. Per-wait total is ~13.3us
(266.5ms/20000), dominated by event-loop/timer machinery, not validation.

## Conclusion

No measurable per-wait overhead from the consolidated guards. Any guard cost
sits below this box's noise floor (about ±0.25us/wait at 20000 waits × 9
reps). The fail-loud wait validation is, for practical purposes, free.

## Caveats

- Noisy shared VM (other workloads running); bun 1.4.2, not the gate minis.
- JS lane only. The C lane's `io_step` guard is unmeasured — no clang here.
- The guarded tree used for timing was fork main overlaid with the repair
  branch's `bend2/comp.ts` (byte-identical to that branch's blob).

## Repro

```
bun bend2/main.ts bench/io-wait-guard-overhead/wait_bench.bend -o /tmp/w.js
time bun /tmp/w.js   # repeat, alternating trees, compare medians
```
