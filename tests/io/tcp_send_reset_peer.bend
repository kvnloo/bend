# io (io_tcp_send_reset_peer): a peer that resets the connection (close with
# unread data in its buffer) must fail a send loudly, never hang it. The
# client sends one byte, waits, then sends again; the second send answers
# Fail{ECONNRESET} in the interp and emitted-JS lanes alike. This locks the
# error leg of tcp_send_more / tcp_send: no test covered the reset path
# before, and a hang here would wedge the whole loop.
import Base

def client.judge(m: Socket & Result<&1, &1, (U32 & String), Unit>) -> IO(Unit):
  (s, r) = m
  match r:
    case Done{u}:
      do IO<Unit>:
        Unit <- Socket.close(s)
        IO.print("no-reset")
    case Fail{e}:
      do IO<Unit>:
        Unit <- Socket.close(s)
        IO.print("reset")

def client.second(m: Socket & Result<&1, &1, (U32 & String), Unit>) -> IO(Unit):
  (s, r) = m
  match r:
    case Done{u}:
      do IO<Unit>:
        m2 : Socket & Result<&1, &1, (U32 & String), Unit> <- TCP.send(s, "C")
        client.judge(m2)
    case Fail{e}:
      do IO<Unit>:
        Unit <- Socket.close(s)
        IO.print("reset")

def client.first(m: Socket & Result<&1, &1, (U32 & String), Unit>) -> IO(Unit):
  (s, r) = m
  match r:
    case Done{u}:
      do IO<Unit>:
        Unit <- IO.sleep(400)
        m2 : Socket & Result<&1, &1, (U32 & String), Unit> <- TCP.send(s, "B")
        client.second(m2)
    case Fail{e}:
      do IO<Unit>:
        Unit <- Socket.close(s)
        IO.print("reset")

def client.got(r: Result<&1, &1, (U32 & String), Socket>) -> IO(Unit):
  match r:
    case Done{s}:
      do IO<Unit>:
        m : Socket & Result<&1, &1, (U32 & String), Unit> <- TCP.send(s, "A")
        client.first(m)
    case Fail{e}:
      IO.print("no-connect")

def client(port: U32) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, (U32 & String), Socket> <- TCP.connect("127.0.0.1", port)
    client.got(r)

def serve.got(m: Listener & Result<&1, &1, (U32 & String), Socket>) -> IO(Unit):
  (l, r) = m
  match r:
    case Done{s}:
      do IO<Unit>:
        Unit <- Listener.close(l)
        Socket.close(s)
    case Fail{e}:
      Listener.close(l)

def serve(l: Listener) -> IO(Unit):
  do IO<Unit>:
    m : Listener & Result<&1, &1, (U32 & String), Socket> <- TCP.accept(l)
    serve.got(m)

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
    Unit <- IO.spawn(Unit, serve(l))
    Unit <- client(p)
    return 0

def main() -> IO(U32):
  do IO<U32>:
    b : Listener & U32 <- tcp_listen_any(32n, 19847)
    main.go(b)

#|reset
