import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';

CockpitCapabilityProfile cockpitMergeTargetCapabilityProfiles({
  required CockpitCapabilityProfile primary,
  CockpitCapabilityProfile? secondary,
}) {
  if (secondary == null) {
    return primary;
  }
  return CockpitCapabilityProfile(
    targetKind: primary.targetKind,
    surfaceKinds: <CockpitSurfaceKind>{
      ...primary.surfaceKinds,
      ...secondary.surfaceKinds,
    },
    actionCapabilities: <CockpitActionCapability>{
      ...primary.actionCapabilities,
      ...secondary.actionCapabilities,
    },
    evidenceCapabilities: <CockpitEvidenceCapability>{
      ...primary.evidenceCapabilities,
      ...secondary.evidenceCapabilities,
    },
    qualityFlags: <CockpitQualityFlag>{
      ...primary.qualityFlags,
      ...secondary.qualityFlags,
    },
  );
}

CockpitSurfaceKind cockpitForegroundSurfaceForTargetProfile(
  CockpitCapabilityProfile profile,
) {
  final preferredSurface = switch (profile.targetKind) {
    CockpitTargetKind.desktopApp => CockpitSurfaceKind.desktopWindow,
    CockpitTargetKind.browserPage => CockpitSurfaceKind.browserDom,
    CockpitTargetKind.hostWorkspace => CockpitSurfaceKind.hostShell,
    CockpitTargetKind.device => CockpitSurfaceKind.deviceShell,
    CockpitTargetKind.systemSurface => CockpitSurfaceKind.systemUi,
    CockpitTargetKind.flutterApp => CockpitSurfaceKind.flutterSemantic,
    CockpitTargetKind.nativeApp => CockpitSurfaceKind.nativeUi,
  };
  if (profile.supportsSurface(preferredSurface)) {
    return preferredSurface;
  }
  for (final surface in <CockpitSurfaceKind>[
    CockpitSurfaceKind.flutterSemantic,
    CockpitSurfaceKind.desktopWindow,
    CockpitSurfaceKind.browserDom,
    CockpitSurfaceKind.nativeUi,
    CockpitSurfaceKind.systemUi,
    CockpitSurfaceKind.deviceShell,
    CockpitSurfaceKind.hostShell,
  ]) {
    if (profile.supportsSurface(surface)) {
      return surface;
    }
  }
  return preferredSurface;
}

CockpitPlaneKind cockpitPlaneForSurface(CockpitSurfaceKind surfaceKind) {
  return switch (surfaceKind) {
    CockpitSurfaceKind.flutterSemantic => CockpitPlaneKind.flutterSemanticPlane,
    CockpitSurfaceKind.nativeUi ||
    CockpitSurfaceKind.desktopWindow ||
    CockpitSurfaceKind.browserDom => CockpitPlaneKind.nativeUiPlane,
    CockpitSurfaceKind.systemUi ||
    CockpitSurfaceKind.deviceShell => CockpitPlaneKind.deviceSystemPlane,
    CockpitSurfaceKind.hostShell => CockpitPlaneKind.hostPlane,
  };
}

List<CockpitPlaneKind> cockpitFallbackTrailForProfile({
  required CockpitCapabilityProfile profile,
  required CockpitPlaneKind selectedPlane,
}) {
  final trail = <CockpitPlaneKind>[];

  void addIfSupported(CockpitPlaneKind planeKind) {
    if (planeKind == selectedPlane || trail.contains(planeKind)) {
      return;
    }
    if (cockpitProfileSupportsPlane(profile, planeKind)) {
      trail.add(planeKind);
    }
  }

  switch (selectedPlane) {
    case CockpitPlaneKind.flutterSemanticPlane:
      addIfSupported(CockpitPlaneKind.nativeUiPlane);
      addIfSupported(CockpitPlaneKind.deviceSystemPlane);
      addIfSupported(CockpitPlaneKind.hostPlane);
    case CockpitPlaneKind.nativeUiPlane:
      addIfSupported(CockpitPlaneKind.deviceSystemPlane);
      addIfSupported(CockpitPlaneKind.hostPlane);
    case CockpitPlaneKind.deviceSystemPlane:
      addIfSupported(CockpitPlaneKind.hostPlane);
    case CockpitPlaneKind.hostPlane:
      break;
  }

  return List<CockpitPlaneKind>.unmodifiable(trail);
}

bool cockpitProfileSupportsPlane(
  CockpitCapabilityProfile profile,
  CockpitPlaneKind planeKind,
) {
  return switch (planeKind) {
    CockpitPlaneKind.flutterSemanticPlane => profile.supportsSurface(
      CockpitSurfaceKind.flutterSemantic,
    ),
    CockpitPlaneKind.nativeUiPlane =>
      profile.supportsSurface(CockpitSurfaceKind.nativeUi) ||
          profile.supportsSurface(CockpitSurfaceKind.desktopWindow) ||
          profile.supportsSurface(CockpitSurfaceKind.browserDom),
    CockpitPlaneKind.deviceSystemPlane =>
      profile.supportsSurface(CockpitSurfaceKind.systemUi) ||
          profile.supportsSurface(CockpitSurfaceKind.deviceShell),
    CockpitPlaneKind.hostPlane => profile.supportsSurface(
      CockpitSurfaceKind.hostShell,
    ),
  };
}

String cockpitRecommendedNextStepForProfile(CockpitCapabilityProfile profile) {
  if (profile.supportsAction(CockpitActionCapability.captureScreenshot)) {
    return 'inspectSurface';
  }
  if (profile.supportsAction(CockpitActionCapability.runShell)) {
    return 'runShell';
  }
  if (profile.supportsSurface(CockpitSurfaceKind.browserDom)) {
    return 'attachBrowserInspector';
  }
  return 'connectTarget';
}

String? cockpitWhatMattersForProfile(CockpitCapabilityProfile profile) {
  if (profile.qualityFlags.contains(CockpitQualityFlag.requiresBrowserDriver)) {
    return 'This target needs an external browser driver for deeper control.';
  }
  if (profile.qualityFlags.contains(CockpitQualityFlag.simulatorOnly)) {
    return 'This target is only supported on simulator environments.';
  }
  if (profile.qualityFlags.contains(
    CockpitQualityFlag.requiresForegroundWindow,
  )) {
    return 'This target must stay foregrounded for reliable control.';
  }
  return null;
}
