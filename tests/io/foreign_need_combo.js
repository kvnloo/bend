// combo_wait: declares a combined {read: true, time: true} need on its
// single word. The runtime must arm both the fd and the deadline and fire
// on whichever comes first. The test passes 0: fd 0 is never readable,
// but the deadline is immediate (0 ms), so the wait must wake at once.
function combo_wait(x) {
  return 42;
}
function combo_wait_need() {
  return { read: true, time: true };
}
