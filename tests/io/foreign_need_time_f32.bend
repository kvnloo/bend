# io (io_foreign_need_time_f32): a time wait's first argument is a
# millisecond count. A `U32` and an `F32` share the tag-0 term layout, so a
# foreign def declaring {time: true} on an `F32` argument made the C lane
# read the float's raw bits as the count (5.0 -> ~12 days) while the JS
# lane waited the value (5ms). The C twin declares `IO_F32` beside
# `IO_TIME`, and the runtime converts the float value to milliseconds.
import Base

law wait_f32:
  F32 -> IO(U32)

def wait_f32(x):
  import "./foreign_need_time_f32.c"
  import "./foreign_need_time_f32.js"

law main:
  IO(U32)

def main():
  do IO<U32>:
    u : Unit <- IO.print("before")
    x : U32 <- wait_f32(5.0)
    v : Unit <- IO.print("after")
    return 0

#|before
#|after
