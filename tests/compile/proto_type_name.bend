# a datatype named __proto__, constructor or toString compiles on both
# lanes: WORDS has no prototype and the printer finds the type's kind in a
# list, so the lookups cannot read Object.prototype through the name
import Base

type __proto__ is Data:
  PA{}
  PB{}

type constructor is Data:
  MkC{v: U32}

def pick(x: __proto__) -> Nat:
  match x:
    case PA{}:
      1n
    case PB{}:
      2n

def get(y: constructor) -> U32:
  match y:
    case MkC{v}:
      v

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(Nat.show(pick(PB{})))
    IO.print(U32.show(get(MkC{41})))

#|2n
#|41
