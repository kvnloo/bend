# io (io_foreign_need_socket_eof): a peer's orderly close is neither an
# error nor a hang. The eof_client sends "Z" then closes; the server's first
# TCP.recv answers "Z" (buffered data arrives before the FIN), the second
# answers "" (the FIN), and a third read answers "" again instead of
# spinning on the hangup. All three lanes print Z, eof, eof.
import Base

def show_str_empty(empty: Bool, s: String) -> IO(Unit):
  match empty:
    case True{}:
      IO.print("eof")
    case False{}:
      IO.print(s)

law show_str:
  for s: String
  IO(Unit)

def show_str(s):
  +s2 = s
  show_str_empty(String.is_empty(s2), s2)

law reads3:
  for m: Socket & Result<&1, &1, U32 & String, String>
  IO(U32)

def reads3(m):
  (s3, r3) = m
  do IO<U32>:
    d3 : String <- IO.pass(String, r3)
    u3 : Unit <- show_str(d3)
    u4 : Unit <- Socket.close(s3)
    return 0

law reads2:
  for m: Socket & Result<&1, &1, U32 & String, String>
  IO(U32)

def reads2(m):
  (s2, r2) = m
  do IO<U32>:
    d2 : String <- IO.pass(String, r2)
    u2 : Unit <- show_str(d2)
    m3 : Socket & Result<&1, &1, U32 & String, String> <- TCP.recv(s2, 8)
    reads3(m3)

law reads1:
  for m: Socket & Result<&1, &1, U32 & String, String>
  IO(U32)

def reads1(m):
  (s1, r1) = m
  do IO<U32>:
    d1 : String <- IO.pass(String, r1)
    u1 : Unit <- show_str(d1)
    m2 : Socket & Result<&1, &1, U32 & String, String> <- TCP.recv(s1, 8)
    reads2(m2)

law reads:
  for s: Socket
  IO(U32)

def reads(s):
  do IO<U32>:
    m1 : Socket & Result<&1, &1, U32 & String, String> <- TCP.recv(s, 8)
    reads1(m1)

law eof_serve_got:
  for p: Listener & Result<&1, &1, U32 & String, Socket>
  IO(U32)

def eof_serve_got(p):
  (l2, ar) = p
  do IO<U32>:
    a : Socket <- IO.pass(Socket, ar)
    u : Unit <- Listener.close(l2)
    reads(a)

law eof_serve:
  for l: Listener
  IO(U32)

def eof_serve(l):
  do IO<U32>:
    p : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    eof_serve_got(p)

law eof_sent_got:
  for m: Socket & Result<&1, &1, U32 & String, Unit>
  IO(Unit)

def eof_sent_got(m):
  (s, r) = m
  do IO<Unit>:
    u1 : Unit <- IO.pass(Unit, r)
    Socket.close(s)

law eof_sent:
  for m: Socket & Result<&1, &1, U32 & String, Unit>
  IO(Unit)

def eof_sent(m):
  eof_sent_got(m)

law eof_client:
  for port: U32
  IO(Unit)

def eof_client(port):
  do IO<Unit>:
    s : Socket <- IO.try(Socket, TCP.connect("127.0.0.1", port))
    m : Socket & Result<&1, &1, U32 & String, Unit> <- TCP.send(s, "Z")
    eof_sent(m)

law eof_main_go:
  for b: Listener & U32
  IO(U32)

def eof_main_go(b):
  (l, port) = b
  do IO<U32>:
    u : Unit <- IO.spawn(U32, eof_serve(l))
    eof_client(port)
    return 0

law eof_tcp_retry:
  for port : U32
  for r    : Result<&1, &1, U32 & String, Listener>
  for rest : IO(Listener & U32)
  IO(Listener & U32)

def eof_tcp_retry(port, r, rest):
  match r:
    case Done{l}:
      IO.pure(Listener & U32, (l, port))
    case Fail{e}:
      rest

law eof_tcp_listen_any:
  for tries : Nat
  for +port : U32
  IO(Listener & U32)

def eof_tcp_listen_any(tries, port):
  match tries:
    case 0n:
      IO.die(Listener & U32, 1, "no free tcp port")
    case 1n+t:
      rest = eof_tcp_listen_any(t, (port + 1 : U32))
      do IO<Listener & U32>:
        r : Result<&1, &1, U32 & String, Listener> <- TCP.listen(port)
        eof_tcp_retry(port, r, rest)

law main:
  IO(U32)

def main():
  do IO<U32>:
    b : Listener & U32 <- eof_tcp_listen_any(32n, 19831)
    eof_main_go(b)

#|Z
#|eof
#|eof
