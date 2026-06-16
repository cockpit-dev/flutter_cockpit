import 'package:cockpit/src/application/cockpit_bundle_artifact_paths.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('ignores delivery artifact refs that escape the bundle directory', () {
    final paths = CockpitBundleArtifactPaths.fromDelivery(
      bundleDir: '/tmp/bundle',
      delivery: const <String, Object?>{
        'primaryScreenshotRef': '../outside.png',
        'attachmentRefs': <String>[
          'screenshots/acceptance.png',
          '/tmp/absolute.png',
        ],
        'primaryRecordingRef': 'recordings/acceptance.mp4',
        'videoAttachmentRefs': <String>['../../outside.mp4'],
        'keyframes': <Map<String, Object?>>[
          <String, Object?>{'ref': 'keyframes/tail.png'},
          <String, Object?>{'ref': '../outside-keyframe.png'},
        ],
      },
    );

    expect(paths.primaryScreenshotPath, isNull);
    expect(paths.attachmentPaths, <String>[
      p.join('/tmp/bundle', 'screenshots/acceptance.png'),
    ]);
    expect(
      paths.primaryRecordingPath,
      p.join('/tmp/bundle', 'recordings/acceptance.mp4'),
    );
    expect(paths.videoAttachmentPaths, isEmpty);
    expect(paths.keyframePaths, <String>[
      p.join('/tmp/bundle', 'keyframes/tail.png'),
    ]);
  });
}
