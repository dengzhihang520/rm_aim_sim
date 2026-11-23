#!/usr/bin/env python3
"""Verify seasonal presets through real simulator processes and public file IPC."""

import argparse
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from local_ipc import LocalClient


def verify(godot, preset):
    channel = "rune_" + uuid.uuid4().hex
    with tempfile.TemporaryDirectory(prefix="rune_integration_") as temporary:
        directory = Path(temporary)
        config = directory / "scenario.cfg"
        config.write_text((ROOT / "configs" / (preset + ".cfg")).read_text()
                          + '\n[ipc]\nchannel="' + channel + '"\n')
        with (directory / "sim.log").open("w+") as log:
            process = subprocess.Popen(
                [godot, "--headless", "--path", str(ROOT), "--", "--remote",
                 "--config=" + str(config)], stdout=log, stderr=subprocess.STDOUT)
            client = None
            try:
                client = LocalClient(channel)
                state = client.read_state()
                expected_mode = 3 if preset.startswith("big_") else 2
                assert state["appearance"]["robot"] == preset, state
                assert state["mode"] == expected_mode, state
                assert state["rune"]["year"] == int(preset[-4:]), state
                assert not state["truth"]["armors"] and not state["camera"]["armors"], state
                client.send(control=True, fire=False, yaw=0.1, pitch=0)
                deadline = time.monotonic() + 4
                while time.monotonic() < deadline:
                    state = client.read_state()
                    client.send(control=True, fire=False, yaw=0.1, pitch=0)
                    if abs(state["gimbal"]["yaw"] - 0.1) < 0.01:
                        break
                else:
                    raise AssertionError("Seasonal target did not execute the normal gimbal command")
                assert state["rune"]["state"] == "ready" and not state["rune"]["targets"], state
                assert state["stats"]["fired"] == 0, state
                print("PASS:", preset, "-> canonical name, mode, empty armor truth, normal control")
            except BaseException:
                log.flush()
                log.seek(0)
                print(log.read(), file=sys.stderr)
                raise
            finally:
                if client is not None:
                    try:
                        client.close()
                    except (OSError, ValueError):
                        pass
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    args = parser.parse_args()
    for preset in ["small_rune_2025", "big_rune_2025", "small_rune_2027", "big_rune_2027"]:
        verify(args.godot, preset)


if __name__ == "__main__":
    main()
