# io (io_foreign_need_read_socket): a foreign effect with an IO_READ need
# on a socket handle, read from a spawned fiber while the peer sends from
# main. The need parks only the reader's computation; the send lands in
# the socket buffer even if it arrives before the reader parks. All three
# lanes print A.
import Base

def Sock.read1(sock: Socket) -> IO(Socket & String):
  import "./foreign_need_read_socket.c"
  import "./foreign_need_read_socket.js"

law reader.got:
  for m: Socket & String
  IO(Unit)

def reader.got(m):
  (s, data) = m
  do IO<Unit>:
    Unit <- Socket.close(s)
    IO.print(data)

law reader:
  for s: Socket
  IO(Unit)

def reader(s):
  do IO<Unit>:
    m : Socket & String <- Sock.read1(s)
    reader.got(m)

law serve.got:
  for m: Listener & Result<&1, &1, (U32 & String), Socket>
  IO(Unit)

def serve.got(m):
  (l, r) = m
  do IO<Unit>:
    s : Socket <- IO.pass(Socket, r)
    Unit <- Listener.close(l)
    reader(s)

law serve:
  for l: Listener
  IO(Unit)

def serve(l):
  do IO<Unit>:
    m : Listener & Result<&1, &1, (U32 & String), Socket> <- TCP.accept(l)
    serve.got(m)

law client.sent:
  for m: Socket & Result<&1, &1, (U32 & String), Unit>
  IO(Unit)

def client.sent(m):
  (s, r) = m
  do IO<Unit>:
    Unit <- IO.pass(Unit, r)
    Socket.close(s)

law client:
  for port: U32
  IO(Unit)

def client(port):
  do IO<Unit>:
    s : Socket <- IO.try(Socket, TCP.connect("127.0.0.1", port))
    m : Socket & Result<&1, &1, (U32 & String), Unit> <- TCP.send(s, "A")
    client.sent(m)

law main.go:
  for b: Listener & U32
  IO(U32)

def main.go(b):
  (l, +port) = b
  do IO<U32>:
    Unit <- IO.spawn(Unit, serve(l))
    Unit <- client(port)
    return 0

law tcp_retry:
  for port : U32
  for r    : Result<&1, &1, (U32 & String), Listener>
  for rest : IO(Listener & U32)
  IO(Listener & U32)

def tcp_retry(port, r, rest):
  match r:
    case Done{l}:
      IO.pure(Listener & U32, (l, port))
    case Fail{e}:
      rest

law tcp_listen_any:
  for tries : Nat
  for +port : U32
  IO(Listener & U32)

def tcp_listen_any(tries, port):
  match tries:
    case 0n:
      IO.die(Listener & U32, 1, "no free tcp port")
    case 1n+t:
      rest = tcp_listen_any(t, (port + 1 : U32))
      do IO<Listener & U32>:
        r : Result<&1, &1, (U32 & String), Listener> <- TCP.listen(port)
        tcp_retry(port, r, rest)

law main:
  IO(U32)

def main():
  do IO<U32>:
    b : Listener & U32 <- tcp_listen_any(32n, 19747)
    main.go(b)

#|A
