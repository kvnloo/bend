// Sock.half_close: shutdown(fd, SHUT_WR). The peer sees an orderly FIN while
// our read side stays open, so a later send still succeeds. Immediate; the
// effect never waits.
#include <stdint.h>
#include <unistd.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/socket.h>

Term sock_half_close_run(Env e, Term* f, IoWork* w) {
  w->hand = (intptr_t)io_hand_v(f[0]);
  int rc = shutdown((int)w->hand, SHUT_WR);
  Term r = rc < 0 ? io_fail(e, (u32)errno, NULL)
                  : io_done(e, term_pak(CID_UNIT, 0));
  return io_tup(e, io_hand(w->hand), r);
}

static void __attribute__((constructor)) sock_half_close_use(void) {
  io_eff(CID_SOCK_HALF_CLOSE, sock_half_close_run, 0);
}
