import os
import subprocess
import sys

def default_jobs():
    try:
        ncpu = int(subprocess.check_output(["sysctl", "-n", "hw.ncpu"], text=True).strip())
        ram = int(subprocess.check_output(["sysctl", "-n", "hw.memsize"], text=True).strip())
    except (OSError, ValueError):
        return 4
    by_ram = max(1, (ram // (1024 ** 3)) * 10 // 25)
    return min(ncpu, by_ram)

pid = os.fork()
if pid > 0:
    print("detached build child pid:", pid)
    sys.exit(0)

os.setsid()
log = open("/Users/hsu/VerSlicer/verslicer_build.log", "w", buffering=1)
os.dup2(log.fileno(), 1)
os.dup2(log.fileno(), 2)
jobs = os.environ.get("JOBS") or str(default_jobs())
os.chdir("/Users/hsu/VerSlicer/build/arm64")
rc = os.system("ninja -f build-Release.ninja -j%s verslicer" % jobs)
exit_code = (rc >> 8) if os.WIFEXITED(rc) else rc
print("NINJA_EXIT=%d" % exit_code)
sys.exit(0)
