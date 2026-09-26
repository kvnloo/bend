# io (io_spawn_send_drain): the 1MB send's EAGAIN -> POLLOUT re-park
# happens in a SPAWNED task while main drains. The writer's write-readiness
# park and the reader's read park interleave across the run queue; every
# byte still lands exactly once. All prints are main-side, totally ordered,
# so the pin is deterministic. (Spawn x foreign READ was pinned by
# foreign_need_read_socket; single-task send re-park by
# foreign_need_send_repark; spawn x WRITE re-park was unpinned.)
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

law sender_sent:
  for m: Socket & Result<&1, &1, U32 & String, Unit>
  IO(Unit)

def sender_sent(m):
  (s, r) = m
  do IO<Unit>:
    u : Unit <- IO.pass(Unit, r)
    Socket.close(s)

# The SPAWNED side: accept, then push 1MB through the socket. The send
# parks on POLLOUT whenever the buffer fills and resumes on the next
# writable wake; main's drain keeps the buffer moving.
law sender_got:
  for p: Listener & Result<&1, &1, (U32 & String), Socket>
  for payload: String
  IO(Unit)

def sender_got(p, payload):
  (l2, ar) = p
  do IO<Unit>:
    s : Socket <- IO.pass(Socket, ar)
    u1 : Unit <- Listener.close(l2)
    m : Socket & Result<&1, &1, U32 & String, Unit> <- TCP.send(s, payload)
    sender_sent(m)

law sender:
  for l: Listener
  for payload: String
  IO(Unit)

def sender(l, payload):
  do IO<Unit>:
    p : Listener & Result<&1, &1, (U32 & String), Socket> <- TCP.accept(l)
    sender_got(p, payload)

law main_go:
  for b: Listener & U32
  IO(U32)

def main_go(b):
  (l, +port) = b
  do IO<U32>:
    u : Unit <- IO.spawn(Unit, sender(l, big(20n, "x")))
    s : Socket <- IO.try(Socket, TCP.connect("127.0.0.1", port))
    total : Nat <- drain_start(s)
    drain_done(total)

law tcp_retry:
  for port : U32
  for r    : Result<&1, &1, U32 & String, Listener>
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
        r : Result<&1, &1, U32 & String, Listener> <- TCP.listen(port)
        tcp_retry(port, r, rest)

law main:
  IO(U32)

def main():
  do IO<U32>:
    b : Listener & U32 <- tcp_listen_any(32n, 19747)
    main_go(b)

#|yes
#|yes
