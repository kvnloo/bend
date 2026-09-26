// Sock.kill: close(fd) but keep the handle. A later send or recv on the
// dead descriptor must fail loud with EBADF, never hang and never pretend
// to succeed. Immediate; the effect never waits.
#include <stdint.h>
#include <unistd.h>
#include <errno.h>

Term sock_kill_run(Env e, Term* f, IoWork* w) {
  w->hand = (intptr_t)io_hand_v(f[0]);
  close((int)w->hand);
  return io_tup(e, io_hand(w->hand),
                io_done(e, term_pak(CID_UNIT, 0)));
}

static void __attribute__((constructor)) sock_kill_use(void) {
  io_eff(CID_SOCK_KILL, sock_kill_run, 0);
}
