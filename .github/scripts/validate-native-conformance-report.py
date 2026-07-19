#!/usr/bin/env python3

import argparse
import json
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("report", type=Path)
    parser.add_argument("--platform", required=True)
    args = parser.parse_args()

    if not args.report.is_file():
        raise SystemExit(f"Native conformance report was not created: {args.report}")

    payload = json.loads(args.report.read_text(encoding="utf-8"))
    report = payload.get("nativePluginConformance")
    assert isinstance(report, dict), payload
    assert report.get("status") == "passed", report
    assert report.get("platform") == args.platform, report

    capabilities = report.get("capabilitySnapshot")
    capture = report.get("capture")
    recording = report.get("recording")
    assertions = report.get("assertions")
    assert isinstance(capabilities, dict), report
    assert isinstance(capture, dict), report
    assert isinstance(recording, dict), report
    assert isinstance(assertions, dict), report
    assert isinstance(capabilities.get("nativeCaptureAvailable"), bool), capabilities
    assert isinstance(capabilities.get("supportsNativeRecording"), bool), capabilities
    assert assertions.get("capabilitySnapshot") is True, assertions

    if args.platform == "web":
        assert capabilities["nativeCaptureAvailable"] is False, capabilities
        assert capabilities["supportsNativeRecording"] is False, capabilities
        assert capture.get("reason") == "nativeCaptureUnavailable", capture
    else:
        assert capabilities["nativeCaptureAvailable"] is True, capabilities
        assert capture.get("validated") is True, capture
        assert capture.get("byteLength", 0) > 0, capture

    if capabilities["supportsNativeRecording"]:
        assert recording.get("duplicateStartRejected") is True, recording
        assert recording.get("completed") is True, recording
        assert recording.get("recordingKind") == "nativeScreen", recording
        assert recording.get("postFinalizeStopRejected") is True, recording
    else:
        assert args.platform in ("ios", "linux", "web"), recording
        assert recording.get("unavailableBranchTested") is True, recording
        assert recording.get("reason") == "recordingUnavailable", recording

    assert assertions.get("acceptanceVideoValidation") is True, assertions


if __name__ == "__main__":
    main()
