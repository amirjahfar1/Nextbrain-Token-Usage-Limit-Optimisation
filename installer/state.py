"""Shared helpers for the installer: what we added to a project is recorded in
<project>/.claude/token-optimisation/installed.json so uninstall removes exactly that and nothing else."""
import hashlib, json, os, shutil, time


def state_dir(proj):
    return os.path.join(proj, ".claude", "token-optimisation")


def load(proj):
    try:
        d = json.load(open(os.path.join(state_dir(proj), "installed.json")))
        return d if isinstance(d, dict) else {}
    except (OSError, ValueError):
        return {}


def save(proj, d):
    os.makedirs(state_dir(proj), exist_ok=True)
    with open(os.path.join(state_dir(proj), "installed.json"), "w") as f:
        json.dump(d, f, indent=2, ensure_ascii=False)
        f.write("\n")


def drop(proj):
    try:
        os.remove(os.path.join(state_dir(proj), "installed.json"))
    except OSError:
        pass


def sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def backup_dir(proj):
    """One backup folder per install run (install.sh exports NEXTBRAIN_BACKUP so every helper shares it)."""
    b = os.environ.get("NEXTBRAIN_BACKUP") or os.path.join(state_dir(proj), "backups", "%s-%d" % (time.strftime("%Y%m%d-%H%M%S"), os.getpid()))
    os.makedirs(b, exist_ok=True)
    return b


def backup(proj, path, name):
    """Copy path to the run's backup folder under name (never overwrites an earlier copy)."""
    if not os.path.lexists(path) or os.path.isdir(path):
        return
    dst = os.path.join(backup_dir(proj), name)
    if not os.path.exists(dst):
        shutil.copy2(path, dst, follow_symlinks=True)


def rmdir_if_empty(path):
    try:
        os.rmdir(path)
        return True
    except OSError:
        return False
