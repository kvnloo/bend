# hashsum: sum over i in [0, 2^(D+LW)) of hash(i), mod 2^32. A fork tree of 2^D
# leaves (one per GPU lane at D=14), each a flat loop over 2^LW indices.
import Base

def hash(+x: U32) -> U32:
  +a = (x * 2654435761 : U32)
  +b = (a .^. (a >> 15n) : U32)
  +c = (b * 2246822519 : U32)
  (c .^. (c >> 13n) : U32)

def leaf(n: Nat, +x: U32, acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      leaf(p, (x + 1 : U32), (acc + hash(x) : U32))

def tree(d: Nat, +k: U32, +lw: Nat, +w: Nat) -> U32:
  match d:
    case 0n:
      leaf(w, (k << lw : U32), 0)
    case 1n++p:
      a b = tree(p, (k << 1n : U32), lw, w) tree(p, ((k << 1n) .|. 1 : U32), lw, w)
      (a + b : U32)

def main() -> IO(Unit):
  IO.print(U32.show(tree!(8n, 0, 8n, 256n)))
