// far.both: declares BOTH read and time needs; the runtime must fail
// loudly rather than wake the C lane spuriously while the JS lane hangs.
#include <stdint.h>
Term far_both_run(Env e, Term* f, IoWork* w) {
  return (Term)7;
}
static void __attribute__((constructor)) far_both_use(void) {
  io_eff(CID_FAR_BOTH, far_both_run, IO_READ | IO_TIME);
}
