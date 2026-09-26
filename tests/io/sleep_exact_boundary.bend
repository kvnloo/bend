# io (io_sleep_exact_boundary): IO.sleep(0) wakes at once -- the deadline is
# now, so the time-only branch of io_wait answers without blocking -- and
# IO.sleep(50) never returns early: the wake condition (at <= now) is read
# off the same clock as IO.now, so the measured elapsed cannot come back
# short of the requested wait.
import Base

law main:
  IO(U32)

def main():
  do IO<U32>:
    t0 : Nat <- IO.now()
    u1 : Unit <- IO.sleep(0)
    p1 : Unit <- IO.print("woke")
    u2 : Unit <- IO.sleep(50)
    t1 : Nat <- IO.now()
    p2 : Unit <- IO.print(Bool.show(Nat.is_ge(Nat.sub(t1, t0), 50n)))
    return 0

#|woke
#|True
