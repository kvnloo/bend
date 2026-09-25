# Witness for emit_intr's argument layouts.
#
# A generic def instantiated at a word type (pick at Bool) compiles to a
# spin that returns a boxed Term; feeding that box straight into a
# bool intrinsic's C template read the box as a u32 and miscompiled
# (bendlang/bend#1026: f and g printed False). emit_intr now converts
# each argument to the intrinsic's declared layout first, so the box is
# unboxed to a word before Bool.or sees it.
import Base

def pick(-A: Data, c: Bool, a: A, b: A) -> A:
  match c:
    case True{}:
      a
    case False{}:
      b

def f(+n: Nat) -> Bool:
  Bool.or(pick(Bool, Nat.is_lt(0n, n), False{}, Nat.is_eq(n, 0n)), True{})

def g(+n: Nat) -> Bool:
  Bool.or(False{}, pick(Bool, Nat.is_lt(0n, n), True{}, False{}))

def h(n: Nat) -> Bool:
  Bool.or(pick(Bool, True{}, False{}, True{}), Nat.is_lt(n, 100n))

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("f " ++ Bool.show(f(5n)) ++ " g " ++ Bool.show(g(5n)) ++ " h " ++ Bool.show(h(5n)))

#|f True g True h True
