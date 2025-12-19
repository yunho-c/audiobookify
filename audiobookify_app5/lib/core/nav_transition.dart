class NavTransitionData {
  final int fromIndex;
  final int toIndex;

  const NavTransitionData({
    required this.fromIndex,
    required this.toIndex,
  });

  bool get isForward => toIndex > fromIndex;
}
