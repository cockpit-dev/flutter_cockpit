abstract interface class CockpitClock {
  DateTime now();
}

final class SystemCockpitClock implements CockpitClock {
  const SystemCockpitClock();

  @override
  DateTime now() => DateTime.now();
}
