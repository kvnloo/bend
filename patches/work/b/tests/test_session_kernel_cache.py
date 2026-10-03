"""A bootstrapped BendTT kernel is reused by later sessions of the same profile, hash-pinned."""
import importlib
import sys
from pathlib import Path

import pytest

PLUGIN = Path(__file__).resolve().parents[1]


@pytest.fixture
def sk(monkeypatch, tmp_path):
    # Import session_kernel without the Hermes plugin __init__ (pure unit test).
    pkg = tmp_path / "bendpkg"
    pkg.mkdir()
    (pkg / "__init__.py").write_text("")
    for name in ("session_kernel.py", "verify_core.py"):
        (pkg / name).write_bytes((PLUGIN / name).read_bytes())
    monkeypatch.syspath_prepend(str(tmp_path))
    for mod in [m for m in sys.modules if m.startswith("bendpkg")]:
        del sys.modules[mod]
    mod = importlib.import_module("bendpkg.session_kernel")

    calls = []
    identity = {"bend": "b" * 64, "base.bend": "c" * 64, "bendtt.lean": "d" * 64}
    monkeypatch.setattr(mod, "runtime_identity", lambda bend: identity)

    def fake_verify(project, proof, *, kernel_override=None, source_env=None, **kw):
        calls.append(kernel_override)
        if kernel_override is None:  # bootstrap: Bend builds the kernel under $HOME
            k = Path(source_env["HOME"]) / ".bend" / "bendtt" / "k" / "bendtt"
            k.parent.mkdir(parents=True)
            k.write_bytes(b"kernel-bytes")
        return {"verdict": "pass", "success": True}

    def fake_identity(bend, env):
        k = Path(env["HOME"]) / ".bend" / "bendtt" / "k" / "bendtt"
        return {"path": str(k), "sha256": mod.file_identity_sha256(str(k))}

    monkeypatch.setattr(mod, "verify", fake_verify)
    monkeypatch.setattr(mod, "kernel_cache_identity", fake_identity)
    return mod, calls


def test_second_session_reuses_cached_kernel(sk, tmp_path):
    mod, calls = sk
    cache = tmp_path / "profile" / "cache" / "bend-kernel"
    first = mod.KernelSession(cache_root=cache)
    assert first.verify("/bend", "/p", "PROOF.bend")["kernel_strategy"] == "session-bootstrap"
    first.close()
    second = mod.KernelSession(cache_root=cache)
    assert second.verify("/bend", "/p", "PROOF.bend")["kernel_strategy"] == "session-pinned"
    assert calls[0] is None and calls[1] is not None and calls[1].startswith(str(cache))


def test_tampered_cache_is_ignored(sk, tmp_path):
    mod, calls = sk
    cache = tmp_path / "cache"
    mod.KernelSession(cache_root=cache).verify("/bend", "/p", "PROOF.bend")
    (kernel,) = cache.glob("*/bendtt")
    kernel.chmod(0o700)
    kernel.write_bytes(b"evil")
    again = mod.KernelSession(cache_root=cache)
    assert again.verify("/bend", "/p", "PROOF.bend")["kernel_strategy"] == "session-bootstrap"


def test_no_cache_root_keeps_old_behaviour(sk):
    mod, calls = sk
    for _ in range(2):
        s = mod.KernelSession()
        assert s.verify("/bend", "/p", "PROOF.bend")["kernel_strategy"] == "session-bootstrap"
        s.close()
    assert calls == [None, None]
