// read_msg: declares a read need but takes a String; the runtime must
// fail loudly rather than park on a non-number fd.
function read_msg(s) {
  return 7;
}
function read_msg_need() {
  return { read: true };
}
