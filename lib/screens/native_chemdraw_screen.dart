import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/molecule_atom.dart';
import '../models/molecule_bond.dart';

class NativeChemDrawScreen extends StatefulWidget {
  const NativeChemDrawScreen({super.key});

  @override
  State<NativeChemDrawScreen> createState() => _NativeChemDrawScreenState();
}

class _NativeChemDrawScreenState extends State<NativeChemDrawScreen> {
  static const List<String> _elements = [
    'C',
    'H',
    'N',
    'O',
    'S',
    'P',
    'F',
    'Cl',
    'Br',
    'I',
  ];

  static const Map<String, double> _atomicWeights = {
    'H': 1.008,
    'C': 12.011,
    'N': 14.007,
    'O': 15.999,
    'S': 32.06,
    'P': 30.974,
    'F': 18.998,
    'Cl': 35.45,
    'Br': 79.904,
    'I': 126.904,
  };

  final List<MoleculeAtom> _atoms = [];
  final List<MoleculeBond> _bonds = [];

  String _selectedElement = 'C';
  int _selectedBondOrder = 1;
  int? _selectedAtomId;
  int? _selectedBondId;
  int? _draggingAtomId;
  int _nextAtomId = 1;
  int _nextBondId = 1;

  MoleculeAtom? _atomById(int id) {
    for (final atom in _atoms) {
      if (atom.id == id) return atom;
    }
    return null;
  }

  int? _hitAtom(Offset point) {
    for (final atom in _atoms.reversed) {
      if ((atom.position - point).distance <= 24) {
        return atom.id;
      }
    }
    return null;
  }

  int? _hitBond(Offset point) {
    for (final bond in _bonds.reversed) {
      final atom1 = _atomById(bond.atom1Id);
      final atom2 = _atomById(bond.atom2Id);
      if (atom1 == null || atom2 == null) continue;

      if (_distanceToSegment(point, atom1.position, atom2.position) <= 12) {
        return bond.id;
      }
    }
    return null;
  }

  double _distanceToSegment(Offset point, Offset start, Offset end) {
    final segment = end - start;
    final lengthSquared = segment.dx * segment.dx + segment.dy * segment.dy;
    if (lengthSquared == 0) return (point - start).distance;

    final t =
        (((point.dx - start.dx) * segment.dx) +
            ((point.dy - start.dy) * segment.dy)) /
        lengthSquared;
    final clamped = t.clamp(0.0, 1.0);
    final projection = Offset(
      start.dx + segment.dx * clamped,
      start.dy + segment.dy * clamped,
    );

    return (point - projection).distance;
  }

  void _handleCanvasTap(Offset position) {
    final atomId = _hitAtom(position);

    if (atomId != null) {
      setState(() {
        _selectedBondId = null;

        if (_selectedAtomId != null && _selectedAtomId != atomId) {
          _addOrUpdateBond(_selectedAtomId!, atomId);
        }

        _selectedAtomId = atomId;
      });
      return;
    }

    final bondId = _hitBond(position);
    if (bondId != null) {
      setState(() {
        _selectedAtomId = null;
        _selectedBondId = bondId;
      });
      return;
    }

    setState(() {
      _atoms.add(
        MoleculeAtom(
          id: _nextAtomId++,
          element: _selectedElement,
          position: position,
        ),
      );
      _selectedAtomId = _atoms.last.id;
      _selectedBondId = null;
    });
  }

  void _addOrUpdateBond(int atom1Id, int atom2Id) {
    final existingIndex = _bonds.indexWhere(
      (bond) => bond.connects(atom1Id, atom2Id),
    );

    if (existingIndex >= 0) {
      final existing = _bonds[existingIndex];
      _bonds[existingIndex] = MoleculeBond(
        id: existing.id,
        atom1Id: existing.atom1Id,
        atom2Id: existing.atom2Id,
        order: _selectedBondOrder,
      );
      _selectedBondId = existing.id;
      return;
    }

    final bond = MoleculeBond(
      id: _nextBondId++,
      atom1Id: atom1Id,
      atom2Id: atom2Id,
      order: _selectedBondOrder,
    );
    _bonds.add(bond);
    _selectedBondId = bond.id;
  }

  void _handlePanStart(DragStartDetails details) {
    final atomId = _hitAtom(details.localPosition);
    setState(() {
      _draggingAtomId = atomId;
      if (atomId != null) {
        _selectedAtomId = atomId;
        _selectedBondId = null;
      }
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final atomId = _draggingAtomId;
    if (atomId == null) return;

    final index = _atoms.indexWhere((atom) => atom.id == atomId);
    if (index < 0) return;

    setState(() {
      _atoms[index] = _atoms[index].copyWith(
        position: _atoms[index].position + details.delta,
      );
    });
  }

  void _handlePanEnd() {
    _draggingAtomId = null;
  }

  void _deleteSelection() {
    setState(() {
      if (_selectedAtomId != null) {
        final atomId = _selectedAtomId!;
        _atoms.removeWhere((atom) => atom.id == atomId);
        _bonds.removeWhere(
          (bond) => bond.atom1Id == atomId || bond.atom2Id == atomId,
        );
        _selectedAtomId = null;
        _selectedBondId = null;
        return;
      }

      if (_selectedBondId != null) {
        _bonds.removeWhere((bond) => bond.id == _selectedBondId);
        _selectedBondId = null;
      }
    });
  }

  void _clearDrawing() {
    setState(() {
      _atoms.clear();
      _bonds.clear();
      _selectedAtomId = null;
      _selectedBondId = null;
      _draggingAtomId = null;
      _nextAtomId = 1;
      _nextBondId = 1;
    });
  }

  Map<String, int> _elementCounts() {
    final counts = <String, int>{};
    for (final atom in _atoms) {
      counts[atom.element] = (counts[atom.element] ?? 0) + 1;
    }
    return counts;
  }

  String _formulaFromCounts(Map<String, int> counts) {
    if (counts.isEmpty) return '-';

    final ordered = <String>[
      if (counts.containsKey('C')) 'C',
      if (counts.containsKey('H')) 'H',
      ...counts.keys
          .where((element) => element != 'C' && element != 'H')
          .toList()
        ..sort(),
    ];

    return ordered.map((element) {
      final count = counts[element] ?? 0;
      return count == 1 ? element : '$element$count';
    }).join();
  }

  double _molecularWeight(Map<String, int> counts) {
    double total = 0;
    for (final entry in counts.entries) {
      total += (_atomicWeights[entry.key] ?? 0) * entry.value;
    }
    return total;
  }

  void _showAnalysis() {
    final counts = _elementCounts();
    final formula = _formulaFromCounts(counts);
    final molecularWeight = _molecularWeight(counts);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Molecular Properties',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                _PropertyRow(label: 'Formula', value: formula),
                _PropertyRow(
                  label: 'Approx. MW',
                  value: counts.isEmpty
                      ? '-'
                      : molecularWeight.toStringAsFixed(3),
                ),
                _PropertyRow(label: 'Atom count', value: '${_atoms.length}'),
                _PropertyRow(label: 'Bond count', value: '${_bonds.length}'),
                const SizedBox(height: 10),
                const Text(
                  'Current MW/formula are calculated from drawn explicit atoms. Implicit hydrogens can be added in a later version.',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _elementToolbar() {
    return Container(
      height: 58,
      color: const Color(0xFF111827),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final element = _elements[index];
          final isSelected = element == _selectedElement;

          return ChoiceChip(
            label: Text(element),
            selected: isSelected,
            selectedColor: const Color(0xFF14B8A6),
            backgroundColor: const Color(0xFF1E293B),
            side: BorderSide(
              color: isSelected ? const Color(0xFF14B8A6) : Colors.white12,
            ),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: FontWeight.w700,
            ),
            onSelected: (_) {
              setState(() {
                _selectedElement = element;
              });
            },
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: _elements.length,
      ),
    );
  }

  Widget _bondButton(String label, int order) {
    final isSelected = _selectedBondOrder == order;

    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            _selectedBondOrder = order;
          });
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: isSelected ? Colors.white : Colors.white70,
          backgroundColor: isSelected
              ? const Color(0x3314B8A6)
              : Colors.transparent,
          side: BorderSide(
            color: isSelected ? const Color(0xFF14B8A6) : Colors.white24,
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _actionToolbar() {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _bondButton('Single', 1),
              const SizedBox(width: 8),
              _bondButton('Double', 2),
              const SizedBox(width: 8),
              _bondButton('Triple', 3),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectedAtomId == null && _selectedBondId == null
                      ? null
                      : _deleteSelection,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFFB7185)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _atoms.isEmpty && _bonds.isEmpty
                      ? null
                      : _clearDrawing,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showAnalysis,
                  icon: const Icon(Icons.analytics_rounded, size: 18),
                  label: const Text('Analyze'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ChemDraw')),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              color: const Color(0xFF0F172A),
              child: const Text(
                'Tap to add atoms. Tap two atoms to bond. Drag atoms to move.',
                style: TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.white,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _handleCanvasTap(details.localPosition),
                  onPanStart: _handlePanStart,
                  onPanUpdate: _handlePanUpdate,
                  onPanEnd: (_) => _handlePanEnd(),
                  child: CustomPaint(
                    painter: _MoleculePainter(
                      atoms: _atoms,
                      bonds: _bonds,
                      selectedAtomId: _selectedAtomId,
                      selectedBondId: _selectedBondId,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            _elementToolbar(),
            _actionToolbar(),
          ],
        ),
      ),
    );
  }
}

class _MoleculePainter extends CustomPainter {
  final List<MoleculeAtom> atoms;
  final List<MoleculeBond> bonds;
  final int? selectedAtomId;
  final int? selectedBondId;

  const _MoleculePainter({
    required this.atoms,
    required this.bonds,
    required this.selectedAtomId,
    required this.selectedBondId,
  });

  MoleculeAtom? _atomById(int id) {
    for (final atom in atoms) {
      if (atom.id == id) return atom;
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bondPaint = Paint()
      ..color = const Color(0xFF111827)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final selectedBondPaint = Paint()
      ..color = const Color(0xFF14B8A6)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    for (final bond in bonds) {
      final atom1 = _atomById(bond.atom1Id);
      final atom2 = _atomById(bond.atom2Id);
      if (atom1 == null || atom2 == null) continue;

      _drawBond(
        canvas,
        atom1.position,
        atom2.position,
        bond.order,
        bond.id == selectedBondId ? selectedBondPaint : bondPaint,
      );
    }

    for (final atom in atoms) {
      final isSelected = atom.id == selectedAtomId;
      final center = atom.position;

      if (isSelected) {
        canvas.drawCircle(
          center,
          20,
          Paint()
            ..color = const Color(0x2214B8A6)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          center,
          20,
          Paint()
            ..color = const Color(0xFF14B8A6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }

      final textPainter = TextPainter(
        text: TextSpan(
          text: atom.element,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final backgroundRect = Rect.fromCenter(
        center: center,
        width: math.max(28, textPainter.width + 12),
        height: 26,
      );
      final backgroundRRect = RRect.fromRectAndRadius(
        backgroundRect,
        const Radius.circular(8),
      );

      canvas.drawRRect(
        backgroundRRect,
        Paint()..color = Colors.white.withValues(alpha: 0.92),
      );
      canvas.drawRRect(
        backgroundRRect,
        Paint()
          ..color = const Color(0xFFE5E7EB)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      textPainter.paint(
        canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  void _drawBond(
    Canvas canvas,
    Offset start,
    Offset end,
    int order,
    Paint paint,
  ) {
    final vector = end - start;
    if (vector.distance == 0) return;

    final unit = vector / vector.distance;
    final normal = Offset(-unit.dy, unit.dx);
    final lineStart = start + unit * 16;
    final lineEnd = end - unit * 16;

    if (order == 1) {
      canvas.drawLine(lineStart, lineEnd, paint);
      return;
    }

    if (order == 2) {
      canvas.drawLine(lineStart + normal * 4, lineEnd + normal * 4, paint);
      canvas.drawLine(lineStart - normal * 4, lineEnd - normal * 4, paint);
      return;
    }

    canvas.drawLine(lineStart, lineEnd, paint);
    canvas.drawLine(lineStart + normal * 6, lineEnd + normal * 6, paint);
    canvas.drawLine(lineStart - normal * 6, lineEnd - normal * 6, paint);
  }

  @override
  bool shouldRepaint(covariant _MoleculePainter oldDelegate) {
    return true;
  }
}

class _PropertyRow extends StatelessWidget {
  final String label;
  final String value;

  const _PropertyRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
