# io (io_foreign_need_read_fracfd): a read wait's first argument must be
# an integer descriptor. A foreign def declaring {read: true} with a
# fractional first argument made the JS lane park on a bogus fd (the
# typeof-number check passed 1.5 through); the runtime normalizes the
# descriptor with the same Number/integer predicate as the fd guard and
# fails loudly instead.
import Base

law read_fd:
  F32 -> IO(U32)

def read_fd(fd):
  import "./foreign_need_read_fracfd.js"

law main:
  IO(U32)

def main():
  do IO<U32>:
    u : Unit <- IO.print("before")
    x : U32 <- read_fd(1.5)
    v : Unit <- IO.print("after")
    return x

#|before
#|bend: a foreign effect waited on read with a non-handle first argument
#|exit 1
