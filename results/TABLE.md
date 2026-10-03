# AODL gate decision: CPython vs Bend 2.0.34 (same host, quiet-lane exclusive)

## Per-decision latency, warm, single request (µs; median of 3 repeats)

Host load at start: ['2.34', '2.01', '2.08']; busiest: ['62.2% Hyprland', '4.8% kube-apiserver', '4.8% kube-controller', '4.8% 2.1.288', '4.8% top']

| config | kernel-routed e2e p50 | p95 | p99 | x A p50 | all-22,079 p50 | p95 | encode p50 | kernel round-trip p50 | p95 | kernel CPU µs/dec | kernel RSS KB |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A CPython validate() | 40.9 | 95.8 | 128.6 | 1.0 | 39.9 | 94.7 | - | - | - | 43.7 (in-proc, all) | - |
| B_adapter_ref_t1 | 232.6 | 584.7 | 626.0 | 5.69 | 101.4 | 465.1 | 49.5 | 180.6 | 474.0 | 153.7 | 6,832 |
| C1_pipe_ref_t1 | 210.7 | 559.2 | 617.7 | 5.16 | 98.0 | 442.5 | 48.4 | 161.4 | 452.6 | 154.7 | 8,836 |
| C2_pipe_ref_default_threads | 212.2 | 561.4 | 602.0 | 5.19 | 99.0 | 446.8 | 48.8 | 162.4 | 453.5 | 153.7 | 8,884 |
| C3_pipe_ref_native_t1 | 211.9 | 566.6 | 610.2 | 5.19 | 98.7 | 444.6 | 48.2 | 162.2 | 458.4 | 155.7 | 7,184 |
| C5_pipe_par_t1 | 212.4 | 560.2 | 614.1 | 5.20 | 100.6 | 451.8 | 49.4 | 162.3 | 450.6 | 152.7 | 8,820 |

## Batched throughput, rerun (median of 3 repeats)

Host load at start: ['11.12', '8.57', '8.31']; busiest: ['109.5% Discord', '99.9% python3.10', '95.2% python', '90.4% python', '90.4% python']. Bend rows: kernel only, 10,019 pre-encoded request lines in one stdin; Python rows: validate() over the same 10,019 kernel-routed documents.

| config | wall µs/decision | decisions/s | CPU µs/decision | peak RSS KB | parity |
| --- | --- | --- | --- | --- | --- |
| A_python_batch_kernel_routed | 50.2 | 19,912 | 50.0 | n/a | ok |
| A_python_batch_all | 46.6 | 21,443 | 46.5 | n/a | ok |
| A_mp10_batch_kernel_routed | 9.0 | 110,743 | n/a | n/a | ok |
| encode_batch_kernel_routed | 54.2 | 18,435 | n/a | n/a | ok |
| C4_batch_ref_t1 | 167.4 | 5,975 | 166.5 | 32,904 | ok |
| C4_batch_ref_default_threads | 161.9 | 6,178 | 161.0 | 30,888 | ok |
| C4_batch_ref_native_t1 | 169.3 | 5,906 | 167.7 | 32,884 | ok |
| C4_batch_ref_t1_pipefed | 183.9 | 5,438 | 182.5 | 8,636 | ok |
| C5_batch_par_t1 | 316.3 | 3,161 | 314.4 | 32,576 | ok |
| C5_batch_par_t2 | 253.0 | 3,952 | 337.1 | 32,944 | ok |
| C5_batch_par_t4 | 184.6 | 5,418 | 314.7 | 37,080 | ok |
| C5_batch_par_t10 | 148.1 | 6,752 | 334.9 | 42,588 | ok |
| C5_batch_par_default_threads | 128.1 | 7,805 | 346.6 | 51,516 | ok |
| C5_batch_par_default_threads_pipefed | 172.6 | 5,795 | 398.1 | 52,688 | ok |
| D_js_run_mode | 460.6 | 2,171 | 727.8 | 559,208 | ok |

Native process start (empty stdin): p50 725 µs

## Batched throughput, run 1 (median of 3 repeats)

Host load at start: ['5.49', '4.89', '4.01']; busiest: ['76.7% kswapd0', '67.1% Hyprland', '62.3% git', '9.6% ssh', '4.8% containerd-shim']. Bend rows: kernel only, 10,019 pre-encoded request lines in one stdin; Python rows: validate() over the same 10,019 kernel-routed documents.

| config | wall µs/decision | decisions/s | CPU µs/decision | peak RSS KB | parity |
| --- | --- | --- | --- | --- | --- |
| A_python_batch_kernel_routed | 47.1 | 21,248 | 47.0 | n/a | ok |
| A_python_batch_all | 42.9 | 23,298 | 42.9 | n/a | ok |
| A_mp10_batch_kernel_routed | 45.5 | 21,961 | n/a | n/a | ok |
| encode_batch_kernel_routed | 50.6 | 19,746 | n/a | n/a | ok |
| C4_batch_ref_t1 | 155.8 | 6,416 | 154.2 | 326,840 | ok |
| C4_batch_ref_default_threads | 151.5 | 6,601 | 151.1 | 326,840 | ok |
| C4_batch_ref_native_t1 | 172.9 | 5,785 | 160.4 | 326,840 | ok |
| C4_batch_ref_t1_pipefed | 162.1 | 6,170 | 161.4 | 326,840 | ok |
| C5_batch_par_t1 | 261.7 | 3,821 | 261.0 | 326,840 | ok |
| C5_batch_par_t2 | 187.2 | 5,342 | 262.5 | 326,840 | ok |
| C5_batch_par_t4 | 135.0 | 7,407 | 245.1 | 326,840 | ok |
| C5_batch_par_t10 | 107.7 | 9,284 | 273.0 | 326,840 | ok |
| C5_batch_par_default_threads | 80.6 | 12,409 | 289.4 | 326,840 | ok |
| C5_batch_par_default_threads_pipefed | 93.1 | 10,737 | 299.4 | 326,840 | ok |
| D_js_run_mode | 415.9 | 2,404 | 649.8 | 558,784 | ok |

Native process start (empty stdin): p50 562 µs

Cold block host load at start: ['11.05', '8.51', '8.29'] (above the PREREG 3.0 noise threshold; not rerun, see README)

## Cold (fresh process, first decision; p50 of 10 µs)

| path | p50 | p95 |
| --- | --- | --- |
| A: python3 process total (start + import + 2 validates) | 32,537 | 40,454 |
| A: import aodl_contract | 5,393 | 6,144 |
| A: first validate() | 83.6 | 166.8 |
| A: second validate() | 52.6 | 90.2 |
| A: python validator process VmHWM KB (bare interpreter -> after import+validate; results/memory.json) | 12,688 -> 17,208 | |
| B: spawn gate + first reply | 662 | 2,123 |
| B: second reply, same process | 131.2 | 224.1 |
| B: gate process peak RSS KB | 2,864 | |
| B-argv: one process per decision (200 docs) | 898 | 1,498 |

Doc: fixture:compile-stop/mesh; argv mismatches vs reference: 0

## One-time costs (s)

| step | wall s (each run) | rc |
| --- | --- | --- |
| bend_build_native | 5.63, 3.98, 4.18 | [0] |
| bend_emit_c | 0.86 | [0] |
| clang_O3_only | 3.07 | [0] |
| check_only_main | 0.15, 0.15, 0.15 | [0] |
| proof_check | 0.17, 0.17, 0.16 | [0] |
| proof_verdict_cold_kernel | 27.77 | [0] |
| proof_verdict_warm_kernel | 0.40, 0.44, 0.41 | [0] |

