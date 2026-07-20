import 'cockpit_api_error.dart';
import 'cockpit_decode_policy.dart';

enum CockpitRecoveryClass {
  abort,
  retry,
  cleanRetry,
  waitAndRetry,
  reconfigure,
  upgrade,
  userAction,
}

abstract final class CockpitRecoveryResolver {
  static CockpitRecoveryClass resolve(
    CockpitApiError error,
    Iterable<String> negotiatedFeatureIds,
  ) {
    final features = negotiatedFeatureIds.toSet();
    switch (error.code) {
      case CockpitErrorCode.invalidRequest:
      case CockpitErrorCode.notFound:
      case CockpitErrorCode.conflict:
      case CockpitErrorCode.unsupportedOperation:
      case CockpitErrorCode.assertionFailed:
      case CockpitErrorCode.applicationFailed:
      case CockpitErrorCode.cancelled:
      case CockpitErrorCode.interrupted:
      case CockpitErrorCode.internalError:
        return CockpitRecoveryClass.abort;
      case CockpitErrorCode.upgradeRequired:
        return CockpitRecoveryClass.upgrade;
      case CockpitErrorCode.authenticationRequired:
      case CockpitErrorCode.authorizationDenied:
        return CockpitRecoveryClass.userAction;
      case CockpitErrorCode.resourceBusy:
        return CockpitRecoveryClass.waitAndRetry;
      case CockpitErrorCode.staleReference:
        return CockpitRecoveryClass.reconfigure;
      case CockpitErrorCode.transportFailed:
      case CockpitErrorCode.driverUnavailable:
      case CockpitErrorCode.evidenceFailed:
        return features.contains(CockpitFoundationFeature.cleanRetry.id)
            ? CockpitRecoveryClass.cleanRetry
            : CockpitRecoveryClass.abort;
      case CockpitErrorCode.locatorNotFound:
        return features.contains(CockpitFoundationFeature.locatorRetry.id)
            ? CockpitRecoveryClass.retry
            : CockpitRecoveryClass.abort;
      default:
        return CockpitRecoveryClass.abort;
    }
  }
}
