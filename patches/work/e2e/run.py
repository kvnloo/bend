import sys, json
sys.path.insert(0, sys.argv[1] + "/pkg")
from bendpkg.session_kernel import KernelSession
bend, fixture, cache = sys.argv[2], sys.argv[3], sys.argv[1] + "/cache"
for i in range(2):
    s = KernelSession(cache_root=cache)
    r = s.verify(bend, fixture, "PROOF.bend", dependency_cache=sys.argv[1] + "/deps")
    print(json.dumps({"session": i, "verdict": r.get("verdict"), "success": r.get("success"),
                      "kernel_strategy": r.get("kernel_strategy")}))
    s.close()
