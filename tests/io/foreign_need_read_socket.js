// Sock.read1: a foreign read parked by a {read: true} need on the socket
// handle. Mirrors tcp_recv.js: the need parks the fiber until the socket
// is readable; a recv that still finds nothing re-parks.
function sock_read1(socket, k) {
  const sys = io_sys();
  const fd = Number(socket);
  const b = new Uint8Array(8);
  const again = sys.mac ? 35 : 11;
  const go = () => {
    const n = Number(sys.recv(fd, sys.ptr(b), 7, 0));
    if (n < 0) {
      const code = sys.errno();
      if (code === again) {
        io_park_on(fd, false, k, go);
        return undefined;
      }
      return io_tup(socket, io_fail(code));
    }
    return io_tup(socket, io_text(b, n));
  };
  return go();
}
function sock_read1_need() {
  return { read: true };
}
