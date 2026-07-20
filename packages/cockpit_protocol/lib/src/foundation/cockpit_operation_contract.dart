import 'cockpit_operation_descriptor.dart';

typedef CockpitOperationInputDecoder<T> = T Function(Object? value);

final class CockpitOperationContract<T> {
  const CockpitOperationContract({
    required this.descriptor,
    required CockpitOperationInputDecoder<T> inputDecoder,
  }) : _inputDecoder = inputDecoder;

  final CockpitOperationDescriptor descriptor;
  final CockpitOperationInputDecoder<T> _inputDecoder;

  void validateInput(Object? input) {
    _inputDecoder(input);
  }
}
