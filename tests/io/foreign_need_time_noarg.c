// A foreign effect whose registered need declares a time wait but whose
// call carries no duration argument: io_step must fail loudly instead of
// reading the request's first field slot (the continuation, for a
// zero-argument request) as the deadline and waiting on that garbage.
Term my_tick_run(Env e, Term* f, IoWork* w) {
  return term_pak(CID_UNIT, 0);
}

static void __attribute__((constructor)) my_tick_use(void) {
  io_eff(CID_MY_TICK, my_tick_run, IO_TIME);
}
