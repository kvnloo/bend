# io (io_foreign_need_combo_deadline): a foreign def declaring a combined
# {read: true, time: true} need on one word must arm BOTH the fd and the
# deadline and fire on whichever comes first. The JS lane's io_run dropped
# the deadline when both were declared (fd-only wait), while the C lane
# arms both; a combined wait with an unreachable fd and an immediate
# deadline hung forever in JS. Here fd 0 is never readable and the shared
# word is 0 ms, so the deadline must wake the wait at once.
import Base

law combo_wait:
  U32 -> IO(U32)

def combo_wait(x):
  import "./foreign_need_combo.js"

law main:
  IO(U32)

def main():
  do IO<U32>:
    u : Unit <- IO.print("before")
    x : U32 <- combo_wait(0)
    u : Unit <- IO.print("after")
    return x

#|before
#|after
