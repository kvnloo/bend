// read_fd: declares a read need but takes a fractional fd; the runtime
// must fail loudly rather than park on a bogus descriptor.
function read_fd(fd) {
  return 7;
}
function read_fd_need() {
  return { read: true };
}
