class LabContextModel {
  final String selectedLabId;
  final String selectedLabName;
  final String principalInvestigatorUid;

  const LabContextModel({
    required this.selectedLabId,
    required this.selectedLabName,
    this.principalInvestigatorUid = '',
  });

  const LabContextModel.empty()
    : selectedLabId = '',
      selectedLabName = '',
      principalInvestigatorUid = '';

  bool get hasSelection {
    return selectedLabId.trim().isNotEmpty && selectedLabName.trim().isNotEmpty;
  }
}
