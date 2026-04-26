class MoleculeBond {
  final int id;
  final int atom1Id;
  final int atom2Id;
  final int order;

  const MoleculeBond({
    required this.id,
    required this.atom1Id,
    required this.atom2Id,
    required this.order,
  });

  bool connects(int firstAtomId, int secondAtomId) {
    return (atom1Id == firstAtomId && atom2Id == secondAtomId) ||
        (atom1Id == secondAtomId && atom2Id == firstAtomId);
  }
}
