class LabContextModel {
  final String selectedLabId;
  final String selectedLabName;

  const LabContextModel({
    required this.selectedLabId,
    required this.selectedLabName,
  });

  const LabContextModel.empty()
      : selectedLabId = '',
        selectedLabName = '';

  bool get hasSelection {
    return selectedLabId.trim().isNotEmpty &&
        selectedLabName.trim().isNotEmpty;
  }
}
