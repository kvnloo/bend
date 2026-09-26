# io (io_tcp_poll_zero_deadline): a deadline that is already due must not
# block. TCP.poll with a 0 ms deadline on a never-readable socket answers
# None in every lane: the JS io_wait clamps Math.ceil(soon - now) to a
# 0 ms poll, the C io_wait sees soon <= now and passes ms = 0, and both
# wake the wait via at <= now with no fd activity. The peer holds the
# connection open and silent; the only event is the due deadline.
import Base

def poller.got3(s: Socket, res: Maybe<&1, String>) -> IO(Unit):
  match res:
    case None{}:
      do IO<Unit>:
        Unit <- Socket.close(s)
        IO.print("poll-none")
    case Some{data}:
      do IO<Unit>:
        Unit <- Socket.close(s)
        IO.print("BAD-poll-some")

def poller.go2(m: Socket & Result<&1, &1, (U32 & String), Maybe<&1, String>>) -> IO(Unit):
  (s, r) = m
  match r:
    case Done{res}:
      poller.got3(s, res)
    case Fail{e}:
      IO.print("poll-failed")

def poller.go(r: Result<&1, &1, (U32 & String), Socket>) -> IO(Unit):
  match r:
    case Done{s}:
      do IO<Unit>:
        m : Socket & Result<&1, &1, (U32 & String), Maybe<&1, String>> <- TCP.poll(s, 64, 0)
        poller.go2(m)
    case Fail{e}:
      IO.print("no-connect")

def poller(port: U32) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, (U32 & String), Socket> <- TCP.connect("127.0.0.1", port)
    poller.go(r)

def serve.hold(m: Listener & Result<&1, &1, (U32 & String), Socket>) -> IO(Unit):
  (l, r) = m
  match r:
    case Done{s}:
      do IO<Unit>:
        Unit <- Listener.close(l)
        Unit <- IO.sleep(1000)
        Socket.close(s)
    case Fail{e}:
      Listener.close(l)

def serve(l: Listener) -> IO(Unit):
  do IO<Unit>:
    m : Listener & Result<&1, &1, (U32 & String), Socket> <- TCP.accept(l)
    serve.hold(m)

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
    Unit <- poller(p)
    return 0

def main() -> IO(U32):
  do IO<U32>:
    b : Listener & U32 <- tcp_listen_any(32n, 19923)
    main.go(b)

#|poll-none
