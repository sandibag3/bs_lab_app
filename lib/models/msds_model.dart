class MsdsModel {
  final String cas;
  final String cid;
  final String name;
  final String molecularFormula;
  final String molecularWeight;
  final String iupacName;
  final String signalWord;
  final List<String> ghsPictograms;
  final List<String> hazardStatements;
  final List<String> precautionaryStatements;
  final String firstAid;
  final String handlingAndStorage;
  final String pubChemUrl;

  const MsdsModel({
    required this.cas,
    required this.cid,
    required this.name,
    required this.molecularFormula,
    required this.molecularWeight,
    required this.iupacName,
    required this.signalWord,
    required this.ghsPictograms,
    required this.hazardStatements,
    required this.precautionaryStatements,
    required this.firstAid,
    required this.handlingAndStorage,
    required this.pubChemUrl,
  });

  bool get hasDetailedSafetyData {
    return signalWord.trim().isNotEmpty ||
        ghsPictograms.isNotEmpty ||
        hazardStatements.isNotEmpty ||
        precautionaryStatements.isNotEmpty ||
        firstAid.trim().isNotEmpty ||
        handlingAndStorage.trim().isNotEmpty;
  }
}
