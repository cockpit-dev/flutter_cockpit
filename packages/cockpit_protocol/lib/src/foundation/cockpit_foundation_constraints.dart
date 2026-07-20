const int cockpitFoundationPageSizeMaximum = 100;
const int cockpitFoundationJsonMaximumDepth = 64;
const int cockpitFoundationJsonMaximumNodes = 65536;

const String cockpitFoundationAbsolutePathPattern =
    r'^(?!.*(?:^|[\\/])(?:\.|\.\.)(?:[\\/]|$))(?!.*\u0000)(?:/|[A-Za-z]:[\\/]|(?:\\\\|//)[^\\/]+[\\/][^\\/]+)';
