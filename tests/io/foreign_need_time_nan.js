// A foreign effect whose _need declares a time wait but whose call carries
// no duration argument: the runtime must fail loudly, not hang on a NaN
// deadline.
function my_tick(k) {
  return { $: "Unit" };
}
function my_tick_need() {
  return { time: true };
}
