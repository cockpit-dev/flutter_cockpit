final class CockpitHttpNetworkObserverConfiguration {
  const CockpitHttpNetworkObserverConfiguration({
    this.maxRetainedEntries = 200,
    this.maxHeaderCount = 24,
    this.maxHeaderValueLength = 256,
    this.maxBodyBytes = 4096,
    this.captureHeaders = true,
    this.captureBodies = true,
  });

  final int maxRetainedEntries;
  final int maxHeaderCount;
  final int maxHeaderValueLength;
  final int maxBodyBytes;
  final bool captureHeaders;
  final bool captureBodies;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitHttpNetworkObserverConfiguration &&
            other.maxRetainedEntries == maxRetainedEntries &&
            other.maxHeaderCount == maxHeaderCount &&
            other.maxHeaderValueLength == maxHeaderValueLength &&
            other.maxBodyBytes == maxBodyBytes &&
            other.captureHeaders == captureHeaders &&
            other.captureBodies == captureBodies;
  }

  @override
  int get hashCode => Object.hash(
    maxRetainedEntries,
    maxHeaderCount,
    maxHeaderValueLength,
    maxBodyBytes,
    captureHeaders,
    captureBodies,
  );
}
