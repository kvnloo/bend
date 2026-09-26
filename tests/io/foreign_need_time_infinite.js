// wait_ms: declares a time need; the twin's return is irrelevant — the
// runtime guards the caller's first argument before the twin runs.
function wait_ms(ms) {
  return 7;
}
function wait_ms_need() {
  return { time: true };
}
