# io (io_tcp_connect_refused): connecting where nothing listens must fail
# loud, deterministically. The test binds a listener on a free port, closes
# it, then connects to that same port: no server can answer, so the kernel
# refuses. Both lanes answer Fail with ECONNREFUSED -- the JS twin reads
# SO_ERROR after the POLLOUT wake, the C twin reads it in tcp_connect_more --
# and both close the failed socket. No print comes from the refused side.
import Base

def conn.go(r: Result<&1, &1, (U32 & String), Socket>) -> IO(Unit):
  match r:
    case Done{s}:
      do IO<Unit>:
        Unit <- Socket.close(s)
        IO.print("BAD-connect-done")
    case Fail{e}:
      IO.print("connect-failed")

def tcp_retry(port: U32, r: Result<&1, &1, (U32 & String), Listener>, rest: IO(Listener & U32)) -> IO(Listener & U32):
  match r:
    case Done{l}:
      IO.pure(Listener & U32, (l, port))
    case Fail{e}:
      rest

def tcp_listen_any(tries: Nat, +port: U32) -> IO(Listener & U32):
  match tries:
    case 0n:
      IO.die(Listener & U32, 1, "no free tcp port")
    case 1n+t:
      rest = tcp_listen_any(t, (port + 1 : U32))
      do IO<Listener & U32>:
        r : Result<&1, &1, (U32 & String), Listener> <- TCP.listen(port)
        tcp_retry(port, r, rest)

def main.go(b: Listener & U32) -> IO(U32):
  (l, port) = b
  +p = port
  do IO<U32>:
    Unit <- Listener.close(l)
    r : Result<&1, &1, (U32 & String), Socket> <- TCP.connect("127.0.0.1", p)
    Unit <- conn.go(r)
    return 0

def main() -> IO(U32):
  do IO<U32>:
    b : Listener & U32 <- tcp_listen_any(32n, 19923)
    main.go(b)

#|connect-failed
