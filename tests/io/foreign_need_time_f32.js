// wait_f32: the JS lane converts the wait word with Number(), so an F32
// argument waits its value in milliseconds with no extra declaration.
function wait_f32(x) {
  return 7;
}
function wait_f32_need() {
  return { time: true };
}
