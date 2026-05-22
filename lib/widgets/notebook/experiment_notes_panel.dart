import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/experiment_note_model.dart';
import '../../services/firestore_access_guard.dart';
import '../../theme/labmate_theme.dart';

class ExperimentNotesPanel extends StatelessWidget {
  final TextEditingController noteController;
  final bool isSavingNote;
  final VoidCallback onAddNote;
  final Stream<List<ExperimentNoteModel>> notesStream;
  final String Function(Timestamp timestamp) formatDateTime;
  final bool expandList;
  final bool compact;
  final bool docked;
  final bool canAddNote;
  final String? readOnlyMessage;

  const ExperimentNotesPanel({
    super.key,
    required this.noteController,
    required this.isSavingNote,
    required this.onAddNote,
    required this.notesStream,
    required this.formatDateTime,
    this.expandList = false,
    this.compact = false,
    this.docked = false,
    this.canAddNote = true,
    this.readOnlyMessage,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final notesList = _NotesStreamList(
      notesStream: notesStream,
      formatDateTime: formatDateTime,
      expandList: expandList,
      compact: compact,
    );

    final composer = canAddNote
        ? LayoutBuilder(
            builder: (context, constraints) {
              final useRowComposer = constraints.maxWidth >= 300 && docked;

              if (useRowComposer) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildInputField()),
                    const SizedBox(width: 8),
                    SizedBox(width: 112, child: _buildAddButton(padded: false)),
                  ],
                );
              }

              return Column(
                children: [
                  _buildInputField(),
                  const SizedBox(height: 8),
                  _buildAddButton(padded: true),
                ],
              );
            },
          )
        : _ReadOnlyBanner(
            message:
                readOnlyMessage ??
                'Read-only view: you are viewing another member\'s notebook.',
          );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 11 : 12),
      decoration: BoxDecoration(
        color: docked ? palette.panelAlt : palette.panel,
        borderRadius: BorderRadius.circular(compact ? 16 : 18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 30,
                width: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  size: 16,
                  color: Color(0xFF5EEAD4),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      docked ? 'Notes Dock' : 'Daily Notes',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 13.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      docked
                          ? 'Progress log and handoff notes'
                          : 'Progress log and updates',
                      style: TextStyle(
                        color: palette.subtleText,
                        fontSize: 11.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          composer,
          const SizedBox(height: 10),
          Text(
            'Updates',
            style: TextStyle(
              color: palette.subtleText,
              fontSize: 11.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (expandList) ...[Expanded(child: notesList)] else notesList,
        ],
      ),
    );
  }

  Widget _buildInputField() {
    return TextField(
      controller: noteController,
      style: const TextStyle(fontSize: 12.6),
      minLines: docked ? 2 : 3,
      maxLines: docked ? 3 : 4,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: 'Add progress, issues, observations, or next steps...',
        hintStyle: const TextStyle(fontSize: 12.2),
        isDense: true,
        filled: true,
        fillColor: Colors.transparent,
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildAddButton({required bool padded}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isSavingNote ? null : onAddNote,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF14B8A6),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: padded ? 12 : 13),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
        icon: isSavingNote
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.note_add_rounded, size: 16),
        label: const Text('Add Note'),
      ),
    );
  }
}

class _ReadOnlyBanner extends StatelessWidget {
  final String message;

  const _ReadOnlyBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBBF24).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFBBF24).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.visibility_outlined,
            size: 16,
            color: Color(0xFFFBBF24),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: palette.mutedText,
                fontSize: 12.0,
                height: 1.38,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesStreamList extends StatelessWidget {
  final Stream<List<ExperimentNoteModel>> notesStream;
  final String Function(Timestamp timestamp) formatDateTime;
  final bool expandList;
  final bool compact;

  const _NotesStreamList({
    required this.notesStream,
    required this.formatDateTime,
    required this.expandList,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final palette = context.labmate;
    return StreamBuilder<List<ExperimentNoteModel>>(
      stream: notesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _MessageCard(
            message: FirestoreAccessGuard.messageFor(snapshot.error),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final notes = snapshot.data ?? [];
        if (notes.isEmpty) {
          return const _MessageCard(
            message:
                'No daily notes yet. Add the first update to start the log.',
          );
        }

        final list = ListView.separated(
          shrinkWrap: !expandList,
          physics: expandList
              ? const AlwaysScrollableScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          itemCount: notes.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final note = notes[index];

            return Container(
              width: double.infinity,
              padding: EdgeInsets.all(compact ? 10 : 11),
              decoration: BoxDecoration(
                color: palette.panelAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        height: 9,
                        width: 9,
                        decoration: const BoxDecoration(
                          color: Color(0xFF5EEAD4),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 1.5,
                        height: compact ? 44 : 52,
                        color: palette.border,
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.note.trim(),
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: compact ? 12.0 : 12.4,
                            height: 1.42,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _NoteMetaChip(
                              icon: Icons.person_outline_rounded,
                              label: note.creatorLabel,
                            ),
                            _NoteMetaChip(
                              icon: Icons.schedule_rounded,
                              label: formatDateTime(note.createdAt),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );

        if (expandList) {
          return Scrollbar(child: list);
        }

        return list;
      },
    );
  }
}

class _NoteMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _NoteMetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.4, color: const Color(0xFF5EEAD4)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 11.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String message;

  const _MessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        message,
        style: TextStyle(color: palette.mutedText, fontSize: 12.2, height: 1.4),
      ),
    );
  }
}
