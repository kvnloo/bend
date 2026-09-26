# io (io_foreign_need_read_time): a foreign effect's _need may declare a
# read wait (on the handle in its first argument) or a time wait (a
# millisecond deadline in its first argument), but not both: the C lane
# woke such a wait after (fd number) milliseconds with nothing readable
# while the JS lane parked on the handle forever. The runtime now fails
# loudly instead of diverging.
import Base

law far.both:
  Listener -> IO(U32)

def far.both(h):
  import "./foreign_need_read_time.c"
  import "./foreign_need_read_time.js"

law go:
  for l: Listener
  IO(Unit)

def go(l):
  do IO<Unit>:
    x : U32 <- far.both(l)
    IO.print("after")

law main:
  IO(Unit)

def main():
  do IO<Unit>:
    Unit <- IO.print("before")
    r : Result<&1, &1, (U32 & String), Listener> <- TCP.listen(0)
    l : Listener <- IO.pass(Listener, r)
    go(l)

#|before
#|Error: bend: a foreign effect cannot wait on both a handle and a deadline
#|exit 1
