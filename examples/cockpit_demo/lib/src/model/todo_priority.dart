enum TodoPriority {
  low(0),
  medium(1),
  high(2),
  urgent(3);

  const TodoPriority(this.storageValue);

  final int storageValue;

  static TodoPriority fromStorage(int value) {
    return values.firstWhere(
      (priority) => priority.storageValue == value,
      orElse: () => TodoPriority.medium,
    );
  }
}
