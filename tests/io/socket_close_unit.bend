# io (io_socket_close_silent): Socket.close's contract is silent success --
# the C twin ignores close(2)'s return value, the JS twin ignores bun:ffi's,
# so a close can never Fail. Listen, connect, accept, then close both socket
# ends and the listener; every close answers Unit. Deterministic: the only
# print is main-side after all closes.
import Base

law close_pair:
  for p: Listener & Result<&1, &1, (U32 & String), Socket>
  for c: Socket
  IO(U32)

def close_pair(p, c):
  (l2, ar) = p
  do IO<U32>:
    s : Socket <- IO.pass(Socket, ar)
    u1 : Unit <- Socket.close(c)
    u2 : Unit <- Socket.close(s)
    u3 : Unit <- Listener.close(l2)
    u4 : Unit <- IO.print("closed")
    return 0

law main:
  IO(U32)

def main():
  do IO<U32>:
    l : Listener <- IO.try(Listener, TCP.listen(19235))
    c : Socket <- IO.try(Socket, TCP.connect("127.0.0.1", 19235))
    p : Listener & Result<&1, &1, (U32 & String), Socket> <- TCP.accept(l)
    close_pair(p, c)

#|closed
