# io (io_tcp_send_half_close): a peer's half-close must not poison the write
# path. The server shuts down only its write side; the client reads "" (the
# FIN), then sends "D", which still lands because the server's read side is
# open. The server's recv answers "D". All three prints land in the interp
# and emitted-JS lanes: the FIN is a read-side event only.
import Base

def Sock.half_close(sock: Socket) -> IO(Socket & Result<&1, &1, (U32 & String), Unit>):
  import "./tcp_send_half_close.c"
  import "./tcp_send_half_close.js"

def server.got2(m: Socket & Result<&1, &1, (U32 & String), String>) -> IO(Unit):
  (s, r) = m
  match r:
    case Done{data}:
      do IO<Unit>:
        Unit <- Socket.close(s)
        Unit <- IO.print("server got")
        IO.print(data)
    case Fail{e}:
      do IO<Unit>:
        Unit <- Socket.close(s)
        IO.print("server recv failed")

def server.got1(m: Socket & Result<&1, &1, (U32 & String), Unit>) -> IO(Unit):
  (s, r) = m
  match r:
    case Done{u}:
      do IO<Unit>:
        m2 : Socket & Result<&1, &1, (U32 & String), String> <- TCP.recv(s, 64)
        server.got2(m2)
    case Fail{e}:
      do IO<Unit>:
        Unit <- Socket.close(s)
        IO.print("half-close failed")

def serve.got(m: Listener & Result<&1, &1, (U32 & String), Socket>) -> IO(Unit):
  (l, r) = m
  match r:
    case Done{s}:
      do IO<Unit>:
        Unit <- Listener.close(l)
        m2 : Socket & Result<&1, &1, (U32 & String), Unit> <- Sock.half_close(s)
        server.got1(m2)
    case Fail{e}:
      Listener.close(l)

def serve(l: Listener) -> IO(Unit):
  do IO<Unit>:
    m : Listener & Result<&1, &1, (U32 & String), Socket> <- TCP.accept(l)
    serve.got(m)

def client.got2(m: Socket & Result<&1, &1, (U32 & String), Unit>) -> IO(Unit):
  (s, r) = m
  match r:
    case Done{u}:
      do IO<Unit>:
        Unit <- Socket.close(s)
        IO.print("client sent")
    case Fail{e}:
      do IO<Unit>:
        Unit <- Socket.close(s)
        IO.print("client send failed")

def client.checked(m: Socket & Bool) -> IO(Unit):
  (s, eof) = m
  match eof:
    case True{}:
      do IO<Unit>:
        Unit <- IO.print("client saw eof")
        m2 : Socket & Result<&1, &1, (U32 & String), Unit> <- TCP.send(s, "D")
        client.got2(m2)
    case False{}:
      do IO<Unit>:
        Unit <- Socket.close(s)
        IO.print("client saw data")

def client.got1(m: Socket & Result<&1, &1, (U32 & String), String>) -> IO(Unit):
  (s, r) = m
  match r:
    case Done{data}:
      client.checked((s, String.is_empty(data)))
    case Fail{e}:
      do IO<Unit>:
        Unit <- Socket.close(s)
        IO.print("client recv failed")

def client.got(r: Result<&1, &1, (U32 & String), Socket>) -> IO(Unit):
  match r:
    case Done{s}:
      do IO<Unit>:
        m : Socket & Result<&1, &1, (U32 & String), String> <- TCP.recv(s, 64)
        client.got1(m)
    case Fail{e}:
      IO.print("no-connect")

def client(port: U32) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, (U32 & String), Socket> <- TCP.connect("127.0.0.1", port)
    client.got(r)

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

#|client saw eof
#|client sent
#|server got
#|D
