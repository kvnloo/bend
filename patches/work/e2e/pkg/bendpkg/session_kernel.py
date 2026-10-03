"""A private BendTT kernel per active Hermes profile, cleaned up on plugin unload."""
from __future__ import annotations

from pathlib import Path
import hashlib
import json
import os
import shutil
import tempfile
import threading

from .verify_core import (
    BendVerifyError, clean_env, file_identity_sha256, kernel_cache_identity, runtime_identity, verify,
)


def _cache_slot(cache_root, identity):
    """One directory per exact Bend installation (bend, base.bend, bendtt.lean hashes)."""
    key = hashlib.sha256(json.dumps(identity, sort_keys=True).encode()).hexdigest()[:32]
    return Path(cache_root) / key


def _load_cached_kernel(cache_root, identity):
    """Return (path, sha256) of a previously bootstrapped kernel, or None.

    The kernel is accepted only if its bytes still hash to the recorded value and
    the slot is private to this user (owner-only, not group/world writable)."""
    if cache_root is None:
        return None
    slot = _cache_slot(cache_root, identity)
    kernel, recorded = slot / "bendtt", slot / "bendtt.sha256"
    try:
        st = slot.stat()
        if st.st_uid != os.getuid() or st.st_mode & 0o077:
            return None
        expected = recorded.read_text().strip()
    except OSError:
        return None
    actual = file_identity_sha256(str(kernel))
    if actual is None or actual != expected:
        return None
    return str(kernel), actual


def _store_kernel(cache_root, identity, source, sha256):
    """Atomically publish a freshly bootstrapped kernel into the per-identity slot."""
    if cache_root is None:
        return
    slot = _cache_slot(cache_root, identity)
    try:
        slot.mkdir(parents=True, exist_ok=True, mode=0o700)
        os.chmod(slot, 0o700)
        with tempfile.NamedTemporaryFile(dir=slot, delete=False) as tmp:
            with open(source, "rb") as src:
                shutil.copyfileobj(src, tmp)
        if file_identity_sha256(tmp.name) != sha256:
            os.unlink(tmp.name)
            return
        os.chmod(tmp.name, 0o500)
        os.replace(tmp.name, slot / "bendtt")
        (slot / "bendtt.sha256").write_text(sha256 + "\n")
    except OSError:
        return  # the cache is an optimisation; the session-private kernel still works


class KernelSession:
    def __init__(self, cache_root=None):
        # cache_root: directory that keeps bootstrapped kernels across sessions
        # (per Hermes profile). None keeps the old behaviour: rebuild every session.
        self._cache_root = cache_root
        self._lock = threading.RLock()
        self._home = None
        self._bend = None
        self._identity = None
        self._kernel = None
        self._kernel_sha = None
        self._closed = False

    def verify(self, bend: str, project: str, proof: str, dependency_cache=None):
        # Serialize within a profile; other profiles own independent sessions.
        with self._lock:
            if self._closed:
                raise BendVerifyError("plugin_unloaded", "Bend plugin was unloaded; start a new verification after enabling it")
            identity = runtime_identity(bend)
            if self._identity is not None and (bend != self._bend or identity != self._identity):
                raise BendVerifyError("bend_integrity", "Bend installation changed; restart Hermes")
            if self._kernel is None:
                cached = _load_cached_kernel(self._cache_root, identity)
                if cached is not None:
                    self._bend, self._identity = bend, identity
                    self._kernel, self._kernel_sha = cached
            if self._kernel is not None:
                result = verify(project, proof, which=lambda _: bend,
                                kernel_override=self._kernel,
                                kernel_expected_sha256=self._kernel_sha,
                                runtime_expected=self._identity, dependency_cache=dependency_cache)
                result["kernel_strategy"] = "session-pinned"
                return result

            home = tempfile.TemporaryDirectory(prefix="hermes-bend-kernel-")
            env = clean_env()
            env["ELAN_HOME"] = env.get("ELAN_HOME") or str(Path.home() / ".elan")
            env["HOME"] = home.name
            try:
                result = verify(project, proof, which=lambda _: bend, source_env=env,
                                runtime_expected=identity, dependency_cache=dependency_cache)
                kernel = kernel_cache_identity(bend, env)
                if result["verdict"] in {"timeout", "unstable"} or not kernel["sha256"]:
                    home.cleanup()
                    result["kernel_strategy"] = "session-uninitialized"
                    if result["success"]:
                        raise BendVerifyError("kernel_integrity", "Bend did not produce an identifiable kernel")
                    return result
                self._home, self._bend, self._identity = home, bend, identity
                self._kernel, self._kernel_sha = kernel["path"], kernel["sha256"]
                _store_kernel(self._cache_root, identity, kernel["path"], kernel["sha256"])
                result["kernel_strategy"] = "session-bootstrap"
                return result
            except BaseException:
                home.cleanup()
                raise

    def close(self):
        with self._lock:
            self._closed = True
            if self._home is not None:
                self._home.cleanup()
            self._home = self._bend = self._identity = self._kernel = self._kernel_sha = None
