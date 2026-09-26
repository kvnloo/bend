# io (io_foreign_need_time_infinite): a time wait's first argument is a
# millisecond count. An infinite duration would park the fiber forever,
# so the runtime fails loudly, exactly like it does for a NaN duration.
import Base

law wait_ms:
  F32 -> IO(U32)

def wait_ms(ms):
  import "./foreign_need_time_infinite.js"

law main:
  IO(U32)

def main():
  do IO<U32>:
    u : Unit <- IO.print("before")
    x : U32 <- wait_ms((1.0 / 0.0 : F32))
    v : Unit <- IO.print("after")
    return x

#|before
#|bend: a foreign effect waited on time with a non-numeric duration
#|exit 1
