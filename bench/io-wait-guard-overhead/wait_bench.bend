# bench (io_wait_guard_overhead): 20000 sequential IO.sleep(0) waits.
# Measures the per-wait cost of the io_run wait guards (finite-duration
# validation, fd checks, arm-both shape) that the
# muse/guards-consolidated-clamp-repair branch adds to RUNTIME_MAIN.
# Run through the emitted-JS lane (bend2/main.ts -o, then bun out.js)
# to keep the checker out of the timed loop.
import Base

law loop:
  for n: Nat
  IO(Unit)

def loop(n):
  match n:
    case 0n:
      do IO<Unit>:
        IO.sleep(0)
    case 1n+k:
      do IO<Unit>:
        u : Unit <- IO.sleep(0)
        loop(k)

law main:
  IO(U32)

def main():
  do IO<U32>:
    u : Unit <- loop(20000n)
    u : Unit <- IO.print("done")
    return 0

#|done
