# io (io_foreign_need_time_f32_race): two spawns race F32 foreign timed
# waits through the IO_F32 decode path; the 50ms fiber must deliver before
# the 300ms one in every lane (deadline ordering under concurrency).
# deliver before the 300ms one in every lane (deadline ordering under
# concurrency, through the new IO_F32 decode path).
import Base

law wait_f32:
  F32 -> IO(U32)

def wait_f32(x):
  import "./foreign_need_time_f32.c"
  import "./foreign_need_time_f32.js"

law racer:
  for ch: Chan(String)
  for ms: F32
  for tag: String
  IO(Bool)

def racer(ch, ms, tag):
  do IO<Bool>:
    x : U32 <- wait_f32(ms)
    Chan.send(String, ch, tag)

law show.got:
  for got: Maybe<&1, String>
  IO(Unit)

def show.got(got):
  match got:
    case None{}:
      IO.print("none")
    case Some{value}:
      IO.print(value)

law main.go:
  for +c: Chan(String)
  IO(U32)

def main.go(c):
  +ch = c
  do IO<U32>:
    s1 : Unit <- IO.spawn(Bool, racer(ch, 300.0, "slow"))
    s2 : Unit <- IO.spawn(Bool, racer(ch, 50.0, "fast"))
    g1 : Maybe<&1, String> <- Chan.recv(String, ch)
    u1 : Unit <- show.got(g1)
    g2 : Maybe<&1, String> <- Chan.recv(String, ch)
    u2 : Unit <- show.got(g2)
    return 0

law main:
  IO(U32)

def main():
  do IO<U32>:
    ch : Chan(String) <- Chan.new(String, 2)
    main.go(ch)

#|fast
#|slow
