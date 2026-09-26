// read_msg: declares IO_READ but takes a String; the runtime must fail
// loudly rather than wait on the term bits decoded as a descriptor.
#include <stdint.h>
Term read_msg_run(Env e, Term* f, IoWork* w) {
  (void)e; (void)f; (void)w;
  return (Term)7;
}
static void __attribute__((constructor)) read_msg_use(void) {
  io_eff(CID_READ_MSG, read_msg_run, IO_READ);
}
