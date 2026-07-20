const int cockpitFoundationPageSizeMaximum = 100;
const int cockpitFoundationRequestMaximumBytes = 1048576;
const int cockpitFoundationJsonMaximumDepth =
    cockpitFoundationRequestMaximumBytes ~/ 2;
const int cockpitFoundationJsonMaximumNodes =
    cockpitFoundationRequestMaximumBytes;

const String cockpitFoundationAbsolutePathPattern =
    r'^(?!.*(?:^|[\\/])(?:\.|\.\.)(?:[\\/]|$))(?!.*\u0000)(?:/|[A-Za-z]:[\\/]|(?:\\\\|//)[^\\/]+[\\/][^\\/]+)';
