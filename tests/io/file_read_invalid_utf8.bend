# io (io_read_invalid_utf8): File.read decodes bytes as WHATWG UTF-8: a lone
# 0xFF, a truncated 0xC3 lead, and a truncated 0xE2 0x82 lead each become
# U+FFFD, while the valid E2 82 80 tail still decodes to U+2080. Written
# with File.write_bytes so no encoder touches the raw bytes first.
import Base

law write_go:
  for w: File & Result<&1, &1, (U32 & String), Unit>
  IO(Unit)

def write_go(w):
  (f, r) = w
  do IO<Unit>:
    u : Unit <- IO.pass(Unit, r)
    File.close(f)

law read_go:
  for m: File & Result<&1, &1, (U32 & String), String>
  IO(U32)

def read_go(m):
  (f, r) = m
  do IO<U32>:
    text : String <- IO.pass(String, r)
    p    : Unit <- IO.print(Bool.show(String.eq(text, "A\u{fffd}B\u{fffd}\u{2080}")))
    x    : Unit <- File.close(f)
    return 0

law main:
  IO(U32)

def main():
  do IO<U32>:
    f : File <- IO.try(File, File.open("/tmp/bend_io_read_invalid_utf8", "w"))
    w : File & Result<&1, &1, (U32 & String), Unit> <-
      File.write_bytes(f, 65 <> 255 <> 66 <> 195 <> 226 <> 130 <> 128 <> Nil{})
    x : Unit <- write_go(w)
    g : File <- IO.try(File, File.open("/tmp/bend_io_read_invalid_utf8", "r"))
    m : File & Result<&1, &1, (U32 & String), String> <- File.read(g, 64)
    read_go(m)

#|True
