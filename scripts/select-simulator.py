"""Select exactly one available iOS simulator from simctl JSON; never guess an OS."""
import argparse
import json
import sys


def select(devices, name, udid="", runtime=""):
    available = [
        (os, device)
        for os, group in devices.items()
        if os.startswith("com.apple.CoreSimulator.SimRuntime.iOS-")
        for device in group
        if device.get("isAvailable")
    ]
    matches = [
        (os, device) for os, device in available
        if (device.get("udid") == udid if udid else device.get("name") == name)
        and (not runtime or os == runtime)
    ]
    if len(matches) != 1:
        candidates = "\n".join(
            f"  {device['name']} | {os} | {device['udid']}"
            for os, device in available
        )
        raise ValueError(
            f"시뮬레이터를 하나로 특정할 수 없습니다: {udid or name} ({runtime or '런타임 미지정'})\n"
            "IOS_SIMULATOR_UDID 또는 IOS_SIMULATOR_NAME + IOS_SIMULATOR_RUNTIME을 지정하세요.\n"
            f"사용 가능한 iOS 시뮬레이터:\n{candidates}"
        )
    return matches[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--name", required=True)
    parser.add_argument("--udid", default="")
    parser.add_argument("--runtime", default="")
    args = parser.parse_args()
    try:
        runtime, device = select(json.load(sys.stdin)["devices"], args.name, args.udid, args.runtime)
    except (ValueError, KeyError, TypeError) as error:
        print(f"오류: {error}", file=sys.stderr)
        return 1
    print(f"시뮬레이터: {device['name']} | {runtime} | {device['udid']}", file=sys.stderr)
    print(device["udid"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
