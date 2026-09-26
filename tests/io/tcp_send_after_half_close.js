// Sock.half_close: shutdown(fd, SHUT_WR). The peer sees an orderly FIN while
// our read side stays open. Immediate; the effect never waits. A later send
// on the write-shut socket fails loud with EPIPE, so send -> half_close ->
// send must answer Done, Done, Fail.
function sock_half_close(socket, k) {
  const sys = io_sys();
  const fd = Number(socket);
  const rc = Number(sys.shutdown(fd, 1));
  if (rc < 0) {
    return io_tup(socket, io_fail(sys.errno()));
  }
  return io_tup(socket, io_done({ $: "Unit" }));
}
