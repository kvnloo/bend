// Sock.read1: a foreign read parked by an IO_READ need on the socket
// handle. Mirrors bend2/effs/tcp_recv.c: the need parks the fiber until
// the socket is readable; a recv that still finds nothing re-parks.
#include <stdint.h>
#include <unistd.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/socket.h>

static Term sock_read1_more(Env e, IoWork* w) {
  char buf[8];
  ssize_t n = recv((int)w->hand, buf, 7, 0);
  if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
    return io_wait_on(w, (int)w->hand, POLLIN, 0, sock_read1_more);
  }
  Term r = n < 0 ? io_fail(e, (u32)errno, NULL)
                 : io_str(e, buf, (u64)n);
  return io_tup(e, io_hand(w->hand), r);
}

Term sock_read1_run(Env e, Term* f, IoWork* w) {
  (void)e;
  w->hand = (intptr_t)io_hand_v(f[0]);
  return sock_read1_more(e, w);
}

static void __attribute__((constructor)) sock_read1_use(void) {
  io_eff(CID_SOCK_READ1, sock_read1_run, IO_READ);
}
