import 'package:flutter/material.dart';

class MoleculeAtom {
  final int id;
  final String element;
  final Offset position;

  const MoleculeAtom({
    required this.id,
    required this.element,
    required this.position,
  });

  MoleculeAtom copyWith({String? element, Offset? position}) {
    return MoleculeAtom(
      id: id,
      element: element ?? this.element,
      position: position ?? this.position,
    );
  }
}
