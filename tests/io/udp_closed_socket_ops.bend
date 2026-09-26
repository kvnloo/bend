# io (io_udp_closed_socket_ops): operations on a closed socket must fail
# loud, never hang and never pretend to succeed. One task, no concurrency:
# bind a UDP socket, kill its fd through the test-local Sock.kill twin
# (close(2), handle kept), then send_to and recv_from on it. Nothing
# allocates an fd after the kill, so the dead number cannot be reused and
# the EBADF is deterministic. Both lanes answer Fail with EBADF(9) -- the
# JS twin reads the raw libc errno, the C twin's io_sys_end records it the
# same way -- and the handle rides outside the Result in both, so the
# second op on the same dead fd is still a clean Fail.
import Base

def Sock.kill(sock: Socket) -> IO(Socket & Result<&1, &1, (U32 & String), Unit>):
  import "./udp_closed_socket_ops.c"
  import "./udp_closed_socket_ops.js"

def closer.recv2(s: Socket, r: Result<&1, &1, (U32 & String), String & U32 & String>) -> IO(Unit):
  match r:
    case Done{v}:
      IO.print("BAD-recv-done")
    case Fail{e}:
      IO.print("recv-failed")

def closer.recv1(m: Socket & Result<&1, &1, (U32 & String), String & U32 & String>) -> IO(Unit):
  (s2, a2) = m
  closer.recv2(s2, a2)

def closer.send2(s: Socket, r: Result<&1, &1, (U32 & String), Unit>) -> IO(Socket):
  match r:
    case Done{v}:
      do IO<Socket>:
        Unit <- IO.print("BAD-send-done")
        return s
    case Fail{e}:
      do IO<Socket>:
        Unit <- IO.print("send-failed")
        return s

def closer.send1(m: Socket & Result<&1, &1, (U32 & String), Unit>) -> IO(Unit):
  (s1, a1) = m
  do IO<Unit>:
    s : Socket <- closer.send2(s1, a1)
    r2 : Socket & Result<&1, &1, (U32 & String), String & U32 & String> <- UDP.recv_from(s, 64)
    closer.recv1(r2)

def closer.kill1(m: Socket & Result<&1, &1, (U32 & String), Unit>) -> IO(Unit):
  (s, r) = m
  match r:
    case Done{v}:
      do IO<Unit>:
        r1 : Socket & Result<&1, &1, (U32 & String), Unit> <- UDP.send_to(s, "127.0.0.1", 9, "x")
        closer.send1(r1)
    case Fail{e}:
      IO.print("BAD-kill-failed")

def main() -> IO(U32):
  do IO<U32>:
    s : Socket <- IO.try(Socket, UDP.bind(0))
    m : Socket & Result<&1, &1, (U32 & String), Unit> <- Sock.kill(s)
    Unit <- closer.kill1(m)
    return 0

#|send-failed
#|recv-failed
