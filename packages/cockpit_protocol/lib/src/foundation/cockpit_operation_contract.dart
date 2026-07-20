import 'cockpit_foundation_value_reader.dart';
import 'cockpit_idempotency.dart';
import 'cockpit_operation_descriptor.dart';

typedef CockpitOperationInputDecoder<T> = T Function(Object? value);
typedef CockpitOperationAdmissionProjector<T> =
    CockpitOperationAdmissionProjection Function(T value);

final class CockpitOperationAdmissionProjection {
  CockpitOperationAdmissionProjection({
    required this.rootId,
    required this.workspaceId,
    required this.idempotencyKey,
    required Iterable<String> requiredFeatures,
  }) : requiredFeatures = List<String>.unmodifiable(requiredFeatures) {
    if (rootId != null) {
      CockpitFoundationValueReader.id(rootId, r'$.rootId');
    }
    if (workspaceId != null) {
      CockpitFoundationValueReader.id(workspaceId, r'$.workspaceId');
    }
    CockpitFoundationValueReader.ids(
      this.requiredFeatures,
      r'$.requiredFeatures',
    );
  }

  const CockpitOperationAdmissionProjection.empty()
    : rootId = null,
      workspaceId = null,
      idempotencyKey = null,
      requiredFeatures = const <String>[];

  final String? rootId;
  final String? workspaceId;
  final CockpitIdempotencyKey? idempotencyKey;
  final List<String> requiredFeatures;
}

final class CockpitOperationContract<T> {
  CockpitOperationContract({
    required this.descriptor,
    required this.requestSchemaRef,
    required CockpitOperationInputDecoder<T> inputDecoder,
    required CockpitOperationAdmissionProjector<T> admissionProjector,
  }) : _inputDecoder = inputDecoder,
       _admissionProjector = admissionProjector {
    CockpitFoundationValueReader.schemaReference(
      requestSchemaRef,
      r'$.requestSchemaRef',
    );
    if (requestSchemaRef != descriptor.requestSchemaRef) {
      throw const FormatException(
        'Operation contract request schema does not match its descriptor.',
      );
    }
  }

  final CockpitOperationDescriptor descriptor;
  final String requestSchemaRef;
  final CockpitOperationInputDecoder<T> _inputDecoder;
  final CockpitOperationAdmissionProjector<T> _admissionProjector;

  CockpitOperationAdmissionProjection decodeAdmission(Object? input) {
    return _admissionProjector(_inputDecoder(input));
  }
}
