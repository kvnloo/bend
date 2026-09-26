// Sock.kill: close(fd) but keep the handle. A later send or recv on the
// dead descriptor must fail loud with EBADF, never hang and never pretend
// to succeed. Immediate; the effect never waits.
function sock_kill(socket, k) {
  const sys = io_sys();
  sys.close(Number(socket));
  return io_tup(socket, io_done({ $: "Unit" }));
}
