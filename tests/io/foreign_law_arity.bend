# io (io_foreign_law_arity): a foreign def must bind every user binder of
# its law, exactly like a local def. Here the law quantifies over a type
# the def never binds; the local twin fails in def_check, while the
# foreign fill used to slip through (its import body is opaque) and
# miscompile: comp.ts sliced the law's domains by def.n, so the value
# argument landed in the continuation slot and the program crashed at
# runtime. The compiler now fails loudly at compile time instead.
import Base

law poly:
  for -a: Type
  a -> IO(String)

def poly(x):
  import "./foreign_law_arity.js"

law main:
  IO(Unit)

def main():
  do IO<Unit>:
    r : String <- poly(Nat, 5n)
    IO.print(r)

#|Error: a foreign def binding 1 parameters for a law with 2: poly
#|exit 1
