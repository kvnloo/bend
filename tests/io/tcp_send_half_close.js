// Sock.half_close: shutdown(fd, SHUT_WR). The peer sees an orderly FIN while
// our read side stays open, so a later send still succeeds. Immediate; the
// effect never waits.
function sock_half_close(socket, k) {
  const sys = io_sys();
  const fd = Number(socket);
  const rc = Number(sys.shutdown(fd, 1));
  if (rc < 0) {
    return io_tup(socket, io_fail(sys.errno()));
  }
  return io_tup(socket, io_done({ $: "Unit" }));
}
