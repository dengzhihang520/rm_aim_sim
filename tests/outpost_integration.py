#!/usr/bin/env python3
"""Exercise the2026 outpost through the existing process and public IPC interfaces."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from local_ipc import LocalClient


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    args = parser.parse_args()
    channel = "outpost_" + uuid.uuid4().hex
    with tempfile.TemporaryDirectory(prefix="outpost_ipc_") as tmp:
        config = Path(tmp) / "scenario.cfg"
        config.write_text((ROOT / "configs/outpost_2026.cfg").read_text()
                          + '\n[ipc]\nchannel="' + channel + '"\n')
        with (Path(tmp) / "sim.log").open("w+") as log:
            proc = subprocess.Popen([args.godot, "--path", str(ROOT), "--headless", "--",
                                     "--config=" + str(config), "--remote"],
                                    stdout=log, stderr=subprocess.STDOUT)
            client = None
            try:
                client = LocalClient(channel)
                state = client.read_state()
                assert state["appearance"]["robot"] == "outpost_2026"
                assert state["mode"] == 1 and len(state["truth"]["armors"]) == 3
                assert state["health"]["current"] == 1500
                assert state["rune"] == {} and state["outpost"]["state"] == "rotating"
                previous_session = state["session_id"]
                camera = state["camera"]["K"]
                deadline = time.monotonic() + 5
                while time.monotonic() < deadline:
                    client.send(control=True, fire=False, yaw=0.1, pitch=0)
                    state = client.read_state()
                    if abs(state["gimbal"]["yaw"] - 0.1) < 0.01:
                        break
                else:
                    raise AssertionError("normal command did not reach the gimbal")
                assert state["session_id"] == previous_session and state["camera"]["K"] == camera
                assert state["stats"]["fired"] == 0 and state["outpost"]["elapsed"] > 0
                print("PASS: outpost canonical preset, three armors, auto-aim mode and normal command feedback")
            except BaseException:
                log.flush()
                log.seek(0)
                print(log.read(), file=sys.stderr)
                raise
            finally:
                if client is not None:
                    client.close()
                proc.terminate()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait()


if __name__ == "__main__":
    main()
