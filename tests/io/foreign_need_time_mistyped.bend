# io (io_foreign_need_time_mistyped): a time wait's first argument is a
# millisecond count. A foreign def declaring {time: true} with a
# non-numeric first argument parked both lanes forever: the JS lane on a
# NaN deadline that never fires, the C lane on whatever the term bits
# decoded to as a deadline. The runtime now fails loudly instead.
import Base

law sleep_msg:
  String -> IO(U32)

def sleep_msg(s):
  import "./foreign_need_time_mistyped.c"
  import "./foreign_need_time_mistyped.js"

law main:
  IO(U32)

def main():
  do IO<U32>:
    u : Unit <- IO.print("before")
    x : U32 <- sleep_msg("hello")
    v : Unit <- IO.print("after")
    return x

#|before
#|bend: a foreign effect waited on time with a non-numeric duration
#|exit 1
