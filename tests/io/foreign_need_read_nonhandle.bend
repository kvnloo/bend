# io (io_foreign_need_read_nonhandle): a read wait's first argument must be
# a handle. A foreign def declaring {read: true} with a String first
# argument made both lanes wait on a bogus descriptor: the C lane decoded
# the term bits as an fd, the JS lane parked on a non-number. The runtime
# now fails loudly instead.
import Base

law read_msg:
  String -> IO(U32)

def read_msg(s):
  import "./foreign_need_read_nonhandle.c"
  import "./foreign_need_read_nonhandle.js"

law main:
  IO(U32)

def main():
  do IO<U32>:
    u : Unit <- IO.print("before")
    x : U32 <- read_msg("hello")
    v : Unit <- IO.print("after")
    return x

#|before
#|bend: a foreign effect waited on read with a non-handle first argument
#|exit 1
