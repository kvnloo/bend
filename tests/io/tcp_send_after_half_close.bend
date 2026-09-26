# io (io_tcp_send_after_half_close): the write-half edge after a local
# half-close. The client sends "A" (Done), half-closes its write side
# (Done), then sends "B": the write-shut socket must fail loud (EPIPE),
# never hang and never silently succeed. The server recvs "A", then ""
# (the FIN) -- asserted with IO.die, so no racy cross-task prints: every
# printed line is client-side and totally ordered.
import Base

def Sock.half_close(sock: Socket) -> IO(Socket & Result<&1, &1, (U32 & String), Unit>):
  import "./tcp_send_after_half_close.c"
  import "./tcp_send_after_half_close.js"

def server.empty2(s: Socket, eof: Bool) -> IO(Unit):
  match eof:
    case True{}:
      Socket.close(s)
    case False{}:
      IO.die(Unit, 1, "server expected FIN second")

def server.got2(m: Socket & Result<&1, &1, (U32 & String), String>) -> IO(Unit):
  (s, r) = m
  match r:
    case Done{data}:
      do IO<Unit>:
        eof : Bool <- IO.pure(Bool, String.is_empty(data))
        server.empty2(s, eof)
    case Fail{e}:
      IO.die(Unit, 1, "server second recv failed")

def server.empty1(s: Socket, eof: Bool) -> IO(Unit):
  match eof:
    case True{}:
      IO.die(Unit, 1, "server expected A first")
    case False{}:
      do IO<Unit>:
        m2 : Socket & Result<&1, &1, (U32 & String), String> <- TCP.recv(s, 64)
        server.got2(m2)

def server.got1(m: Socket & Result<&1, &1, (U32 & String), String>) -> IO(Unit):
  (s, r) = m
  match r:
    case Done{data}:
      do IO<Unit>:
        eof : Bool <- IO.pure(Bool, String.is_empty(data))
        server.empty1(s, eof)
    case Fail{e}:
      IO.die(Unit, 1, "server first recv failed")

def serve.got(m: Listener & Result<&1, &1, (U32 & String), Socket>) -> IO(Unit):
  (l, r) = m
  match r:
    case Done{s}:
      do IO<Unit>:
        Unit <- Listener.close(l)
        m2 : Socket & Result<&1, &1, (U32 & String), String> <- TCP.recv(s, 64)
        server.got1(m2)
    case Fail{e}:
      Listener.close(l)

def serve(l: Listener) -> IO(Unit):
  do IO<Unit>:
    m : Listener & Result<&1, &1, (U32 & String), Socket> <- TCP.accept(l)
    serve.got(m)

def client.sent2(m: Socket & Result<&1, &1, (U32 & String), Unit>) -> IO(Unit):
  (s, r) = m
  match r:
    case Done{u}:
      do IO<Unit>:
        Unit <- Socket.close(s)
        IO.print("BAD-second-send-succeeded")
    case Fail{e}:
      do IO<Unit>:
        Unit <- Socket.close(s)
        Unit <- IO.print("second-send-failed")
        IO.print("done")

def client.halfclosed(m: Socket & Result<&1, &1, (U32 & String), Unit>) -> IO(Unit):
  (s, r) = m
  match r:
    case Done{u}:
      do IO<Unit>:
        Unit <- IO.print("half-closed")
        m2 : Socket & Result<&1, &1, (U32 & String), Unit> <- TCP.send(s, "B")
        client.sent2(m2)
    case Fail{e}:
      IO.print("half-close-failed")

def client.sent1(m: Socket & Result<&1, &1, (U32 & String), Unit>) -> IO(Unit):
  (s, r) = m
  match r:
    case Done{u}:
      do IO<Unit>:
        Unit <- IO.print("sent")
        m2 : Socket & Result<&1, &1, (U32 & String), Unit> <- Sock.half_close(s)
        client.halfclosed(m2)
    case Fail{e}:
      IO.print("first-send-failed")

def client.go(r: Result<&1, &1, (U32 & String), Socket>) -> IO(Unit):
  match r:
    case Done{s}:
      do IO<Unit>:
        m : Socket & Result<&1, &1, (U32 & String), Unit> <- TCP.send(s, "A")
        client.sent1(m)
    case Fail{e}:
      IO.print("no-connect")

def client(port: U32) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, (U32 & String), Socket> <- TCP.connect("127.0.0.1", port)
    client.go(r)

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
    b : Listener & U32 <- tcp_listen_any(32n, 19911)
    main.go(b)

#|sent
#|half-closed
#|second-send-failed
#|done
