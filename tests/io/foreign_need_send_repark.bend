# io (io_foreign_need_send_repark): a send larger than the socket buffer
# exercises the EAGAIN -> POLLOUT re-park path in TCP.send's twin
# (tcp_send_more, ask=0 + a manual io_wait_on / io_park_on): the writer
# parks until the socket is writable again while the reader drains. All
# 1048576 bytes arrive intact in every lane. The reader needs no
# empty/threshold check: recv-after-close answers "" at once, which
# contributes 0, and a structural fuel Nat bounds the loop.
import Base

# 2^20 bytes by doubling.
law big:
  for n: Nat
  for s: String
  String

def big(n, s):
  match n:
    case 0n:
      s
    case 1n+m:
      +s2 = s
      big(m, String.append(s2, s2))

law yesno:
  for ok: Bool
  String

def yesno(ok):
  match ok:
    case True{}:
      "yes"
    case False{}:
      "no"

# Drain until fuel runs out. "" (orderly close) contributes 0 and the
# loop keeps going; fuel is the only match, so no nested matches occur.
law drain:
  for f: Nat
  for n: Nat
  for m: Socket & Result<&1, &1, U32 & String, String>
  IO(Nat)

def drain(f, n, m):
  match f:
    case 0n:
      IO.pure(Nat, n)
    case 1n+g:
      (s, r) = m
      do IO<Nat>:
        d : String <- IO.pass(String, r)
        m2 : Socket & Result<&1, &1, U32 & String, String> <- TCP.recv(s, 65536)
        drain(g, Nat.add(n, String.length(d)), m2)

law drain_start:
  for s: Socket
  IO(Nat)

def drain_start(s):
  do IO<Nat>:
    m : Socket & Result<&1, &1, U32 & String, String> <- TCP.recv(s, 65536)
    drain(10000n, 0n, m)

law drain_done:
  for total: Nat
  IO(U32)

def drain_done(total):
  +t2 = total
  ok1 = Nat.is_ge(t2, 1048576n)
  ok2 = Nat.is_ge(1048576n, t2)
  do IO<U32>:
    u1 : Unit <- IO.print(yesno(ok1))
    u2 : Unit <- IO.print(yesno(ok2))
    return 0

law repark_serve_got:
  for p: Listener & Result<&1, &1, U32 & String, Socket>
  IO(U32)

def repark_serve_got(p):
  (l2, ar) = p
  do IO<U32>:
    a : Socket <- IO.pass(Socket, ar)
    u1 : Unit <- Listener.close(l2)
    total : Nat <- drain_start(a)
    drain_done(total)

law repark_serve:
  for l: Listener
  IO(U32)

def repark_serve(l):
  do IO<U32>:
    p : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    repark_serve_got(p)

law send_done:
  for m: Socket & Result<&1, &1, U32 & String, Unit>
  IO(Unit)

def send_done(m):
  (s, r) = m
  do IO<Unit>:
    u1 : Unit <- IO.pass(Unit, r)
    Socket.close(s)

law send_client:
  for port: U32
  for payload: String
  IO(Unit)

def send_client(port, payload):
  do IO<Unit>:
    s : Socket <- IO.try(Socket, TCP.connect("127.0.0.1", port))
    m : Socket & Result<&1, &1, U32 & String, Unit> <- TCP.send(s, payload)
    send_done(m)

law repark_main_go:
  for b: Listener & U32
  IO(U32)

def repark_main_go(b):
  (l, port) = b
  do IO<U32>:
    u : Unit <- IO.spawn(U32, repark_serve(l))
    send_client(port, big(20n, "x"))
    return 0

law repark_tcp_retry:
  for port : U32
  for r    : Result<&1, &1, U32 & String, Listener>
  for rest : IO(Listener & U32)
  IO(Listener & U32)

def repark_tcp_retry(port, r, rest):
  match r:
    case Done{l}:
      IO.pure(Listener & U32, (l, port))
    case Fail{e}:
      rest

law repark_tcp_listen_any:
  for tries : Nat
  for +port : U32
  IO(Listener & U32)

def repark_tcp_listen_any(tries, port):
  match tries:
    case 0n:
      IO.die(Listener & U32, 1, "no free tcp port")
    case 1n+t:
      rest = repark_tcp_listen_any(t, (port + 1 : U32))
      do IO<Listener & U32>:
        r : Result<&1, &1, U32 & String, Listener> <- TCP.listen(port)
        repark_tcp_retry(port, r, rest)

law main:
  IO(U32)

def main():
  do IO<U32>:
    b : Listener & U32 <- repark_tcp_listen_any(32n, 19911)
    repark_main_go(b)

#|yes
#|yes
