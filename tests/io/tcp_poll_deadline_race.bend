# io (io_tcp_poll_deadline_race): a deadline wait must neither starve nor be
# starved by another task's later deadline. The main task parks on TCP.poll
# with a 150 ms deadline (an fd+clock wait: io_park_on with both fd and at);
# a spawned task parks on IO.sleep for 400 ms (a clock-only wait). The
# poll's deadline fires first, so "poll-none" prints before "slept". The
# peer never sends: the fd never becomes readable, and the race is purely
# between the two deadlines in the loop's io_wait.
import Base

def sleeper() -> IO(Unit):
  do IO<Unit>:
    Unit <- IO.sleep(400)
    IO.print("slept")

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
        m : Socket & Result<&1, &1, (U32 & String), Maybe<&1, String>> <- TCP.poll(s, 64, 150)
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
    Unit <- IO.spawn(Unit, sleeper())
    Unit <- poller(p)
    return 0

def main() -> IO(U32):
  do IO<U32>:
    b : Listener & U32 <- tcp_listen_any(32n, 19923)
    main.go(b)

#|poll-none
#|slept
