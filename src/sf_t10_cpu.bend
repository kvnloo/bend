# signflip: a sign-flip permutation test over n = 2^LN synthetic integer deltas,
# R = 2^(D+LM) resamples. Resample r flips delta j when hash(r*n + j) has its top
# bit clear; prints the count of resamples with |T_r| >= |T_0|. Deterministic, so
# the NumPy/CPython baselines must print the same count.
import Base

def hash(+x: U32) -> U32:
  +a = (x * 2654435761 : U32)
  +b = (a .^. (a >> 15n) : U32)
  +c = (b * 2246822519 : U32)
  (c .^. (c >> 13n) : U32)

def pick(c: Bool, x: U32, y: U32) -> U32:
  match c:
    case True{}:
      x
    case False{}:
      y

def abs(+t: U32) -> U32:
  pick(U32.is_ge(t, 2147483648), (0 - t : U32), t)

def delta(+j: U32) -> U32:
  ((hash((j .^. 2654435769 : U32)) >> 22n) - 511 : U32)

def stat(n: Nat, +base: U32, +j: U32, acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      +s = (hash((base .|. j : U32)) >> 31n : U32)
      +m = (0 - s : U32)
      +d = delta(j)
      stat(p, base, (j + 1 : U32), (acc + ((d .^. m) + s) : U32))

def obs(n: Nat, +j: U32, acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      obs(p, (j + 1 : U32), (acc + delta(j) : U32))

def count(m: Nat, +r: U32, +t0: U32, +ln: Nat, +n: Nat, acc: U32) -> U32:
  match m:
    case 0n:
      acc
    case 1n+p:
      +t = abs(stat(n, (r << ln : U32), 0, 0))
      count(p, (r + 1 : U32), t0, ln, n, (acc + pick(U32.is_ge(t, t0), 1, 0) : U32))

def tree(d: Nat, +k: U32, +lm: Nat, +m: Nat, +t0: U32, +ln: Nat, +n: Nat) -> U32:
  match d:
    case 0n:
      count(m, (k << lm : U32), t0, ln, n, 0)
    case 1n++p:
      a b = tree(p, (k << 1n : U32), lm, m, t0, ln, n) tree(p, ((k << 1n) .|. 1 : U32), lm, m, t0, ln, n)
      (a + b : U32)

def main() -> IO(Unit):
  +t0 = abs(obs(256n, 0, 0))
  IO.print(U32.show(tree(2n, 0, 8n, 256n, t0, 8n, 256n)))
