const String addCustomDropdownOptionLabel = 'Add custom...';

List<String> mergeUniqueOptions(
  List<String> builtInOptions,
  List<String> customOptions,
) {
  final seen = <String>{};
  final merged = <String>[];

  void addOption(String value) {
    final trimmed = value.trim();
    final normalized = trimmed.toLowerCase();

    if (trimmed.isEmpty ||
        normalized == addCustomDropdownOptionLabel.toLowerCase() ||
        seen.contains(normalized)) {
      return;
    }

    seen.add(normalized);
    merged.add(trimmed);
  }

  for (final option in builtInOptions) {
    addOption(option);
  }

  for (final option in customOptions) {
    addOption(option);
  }

  return merged;
}
