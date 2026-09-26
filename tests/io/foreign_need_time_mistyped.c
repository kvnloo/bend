// sleep_msg: declares IO_TIME but takes a String; the runtime must fail
// loudly rather than park on the term bits decoded as a deadline.
#include <stdint.h>
Term sleep_msg_run(Env e, Term* f, IoWork* w) {
  (void)e; (void)f; (void)w;
  return (Term)7;
}
static void __attribute__((constructor)) sleep_msg_use(void) {
  io_eff(CID_SLEEP_MSG, sleep_msg_run, IO_TIME);
}
