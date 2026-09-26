// wait_f32: declares IO_TIME on an F32 wait word, so it also sets IO_F32;
// the runtime converts the float value to milliseconds rather than
// reading the term's raw bits as a count.
#include <stdint.h>
Term wait_f32_run(Env e, Term* f, IoWork* w) {
  (void)e; (void)f; (void)w;
  return (Term)7;
}
static void __attribute__((constructor)) wait_f32_use(void) {
  io_eff(CID_WAIT_F32, wait_f32_run, IO_TIME | IO_F32);
}
