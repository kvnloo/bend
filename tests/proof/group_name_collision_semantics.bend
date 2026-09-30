# regression for source/BendTT group routing: a same-named later def
# must not make a non-member call enter that def's mutual-recursion group.
# bendlang/bend#1212
import Base
import ./group_name_collision_semantics_lib.bend as AB

def a_2d_b.M(n: Nat) -> Bool:
  AB.ign(AB.L(n), False{})

def AB.L(n):
  match n:
    case 0n:
      True{}
    case 1n+p:
      AB.M(p)

def main() -> Bool:
  a_2d_b.M(0n)

law main_is_false:
  {main == False{} : Bool}

def main_is_false():
  {==}

#|False{}
