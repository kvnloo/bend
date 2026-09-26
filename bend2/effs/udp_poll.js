// UDP
// ===

function udp_poll(socket, max) {
  const sys = io_sys();
  const fd = socket;
  const len = Math.min(Number(max), 2147483647);
  const b = new Uint8Array(Math.max(len, 1));
  const peer = new Uint8Array(16);
  const plen = new Uint32Array([16]);
  const got = sys.recvfrom(fd, sys.ptr(b), len, 0, sys.ptr(peer),
    sys.ptr(plen));
  const n = Number(got);
  if (n < 0 && sys.errno() === (sys.mac ? 35 : 11)) {
    return io_tup(socket, io_done({ $: "None" }));
  }
  if (n < 0) {
    return io_tup(socket, io_fail(sys.errno()));
  }
  const host = peer[4] + "." + peer[5] + "." + peer[6] + "." + peer[7];
  const port = (peer[2] << 8) | peer[3];
  return io_tup(socket, io_done({ $: "Some",
    value: io_tup(host, port, io_text(b, n)) }));
}
