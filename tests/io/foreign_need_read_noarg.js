// A foreign effect whose _need declares a read wait but whose call carries
// no file-descriptor argument: the runtime must fail loudly, not hang on a
// bogus wait.
function my_read(k) {
  return { $: "Unit" };
}
function my_read_need() {
  return { read: true };
}
