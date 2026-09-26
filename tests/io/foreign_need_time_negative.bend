# io (io_foreign_need_time_negative): a time wait's first argument is a
# millisecond count. A finite negative duration is already expired: the
# runtime wakes at once rather than failing loudly (a NaN or infinite
# duration is the garbage case the guard rejects).
import Base

law wait_ms:
  F32 -> IO(U32)

def wait_ms(ms):
  import "./foreign_need_time_negative.js"

law main:
  IO(U32)

def main():
  do IO<U32>:
    u : Unit <- IO.print("before")
    x : U32 <- wait_ms((0.0 - 5.0 : F32))
    v : Unit <- IO.print("after")
    return x

#|before
#|after
