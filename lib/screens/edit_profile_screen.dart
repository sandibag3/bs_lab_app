import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/user_profile.dart';

class EditProfileScreen extends StatefulWidget {
  final AppState appState;

  const EditProfileScreen({super.key, required this.appState});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const List<String> _prefixes = ['Mr', 'Ms', 'Dr'];
  static const List<String> _joinAsOptions = [
    'PI',
    'PhD Scholar',
    'Undergrad Student',
    'Project Student',
    'Postdoc Fellow',
    'Lab Manager',
  ];

  late String selectedPrefix;
  late String selectedJoinAs;
  late final TextEditingController nameController;
  late final TextEditingController contactController;
  late final TextEditingController dobController;
  late final TextEditingController rollController;
  late final TextEditingController batchController;
  late final TextEditingController presentAddressController;
  late final TextEditingController permanentAddressController;
  late final TextEditingController emergencyPersonController;
  late final TextEditingController relationshipController;
  late final TextEditingController emergencyNumberController;
  late final TextEditingController bloodGroupController;
  String selectedPhotoPath = '';
  String selectedPhotoName = '';

  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.appState.profile;

    selectedPrefix = _prefixes.contains(profile.prefix)
        ? profile.prefix
        : _prefixes.first;
    selectedJoinAs = _joinAsOptions.contains(profile.joinAs)
        ? profile.joinAs
        : '';
    nameController = TextEditingController(
      text: profile.name == 'Your Name' ? '' : profile.name,
    );
    contactController = TextEditingController(text: profile.contactNumber);
    dobController = TextEditingController(text: profile.dob);
    rollController = TextEditingController(text: profile.rollNo);
    batchController = TextEditingController(text: profile.batch);
    presentAddressController = TextEditingController(
      text: profile.presentAddress,
    );
    permanentAddressController = TextEditingController(
      text: profile.permanentAddress,
    );
    emergencyPersonController = TextEditingController(
      text: profile.emergencyContactPerson,
    );
    relationshipController = TextEditingController(
      text: profile.emergencyRelationship,
    );
    emergencyNumberController = TextEditingController(
      text: profile.emergencyContactNumber,
    );
    bloodGroupController = TextEditingController(text: profile.bloodGroup);
    selectedPhotoPath = profile.photoUrl;
    selectedPhotoName = _photoSelectionLabel(profile.photoUrl);
  }

  @override
  void dispose() {
    nameController.dispose();
    contactController.dispose();
    dobController.dispose();
    rollController.dispose();
    batchController.dispose();
    presentAddressController.dispose();
    permanentAddressController.dispose();
    emergencyPersonController.dispose();
    relationshipController.dispose();
    emergencyNumberController.dispose();
    bloodGroupController.dispose();
    super.dispose();
  }

  bool get _showAcademicFields {
    return selectedJoinAs == 'PhD Scholar' ||
        selectedJoinAs == 'Undergrad Student';
  }

  String _fileNameFromPath(String path) {
    final cleanPath = path.trim();
    if (cleanPath.isEmpty) {
      return '';
    }

    return cleanPath.split(RegExp(r'[\\/]')).last;
  }

  String _photoSelectionLabel(String reference) {
    final avatar = UserProfile.scientificAvatarFromReference(reference);
    if (avatar != null) {
      return 'Scientific avatar: ${avatar.label}';
    }

    return _fileNameFromPath(reference);
  }

  ImageProvider<Object>? _resolvePhotoImageProvider(String reference) {
    final cleanReference = reference.trim();
    if (cleanReference.isEmpty ||
        UserProfile.isScientificAvatarReference(cleanReference)) {
      return null;
    }

    final uri = Uri.tryParse(cleanReference);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https')) {
      return NetworkImage(cleanReference);
    }

    if (uri != null && uri.scheme == 'file') {
      final file = File.fromUri(uri);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }

    final file = File(cleanReference);
    if (file.existsSync()) {
      return FileImage(file);
    }

    return null;
  }

  String _fallbackInitials() {
    final typedName = nameController.text.trim();
    final savedName = widget.appState.authenticatedUserName.trim();
    final fallbackEmail = widget.appState.authenticatedUserEmail.trim();
    final identity = typedName.isNotEmpty
        ? typedName
        : savedName.isNotEmpty
        ? savedName
        : fallbackEmail;

    if (identity.isEmpty) {
      return 'U';
    }

    final words = identity
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList();

    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }

    final cleanIdentity = identity.contains('@')
        ? identity.split('@').first
        : identity;
    if (cleanIdentity.isEmpty) {
      return 'U';
    }

    final maxLength = cleanIdentity.length >= 2 ? 2 : 1;
    return cleanIdentity.substring(0, maxLength).toUpperCase();
  }

  void _selectScientificAvatar(UserProfileScientificAvatar option) {
    setState(() {
      selectedPhotoPath = option.reference;
      selectedPhotoName = 'Scientific avatar: ${option.label}';
    });
  }

  Widget _buildPhotoFallback(String initials) {
    return Container(
      color: const Color(0xFF1E293B),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildProfilePhotoPreview() {
    final avatar = UserProfile.scientificAvatarFromReference(selectedPhotoPath);
    final imageProvider = avatar == null
        ? _resolvePhotoImageProvider(selectedPhotoPath)
        : null;
    final initials = _fallbackInitials();

    return Container(
      height: 90,
      width: 90,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ClipOval(
        child: avatar != null
            ? Container(
                color: const Color(0xFF1E293B),
                alignment: Alignment.center,
                child: Icon(
                  avatar.icon,
                  size: 42,
                  color: const Color(0xFF14B8A6),
                ),
              )
            : imageProvider == null
            ? _buildPhotoFallback(initials)
            : Image(
                image: imageProvider,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPhotoFallback(initials);
                },
              ),
      ),
    );
  }

  Future<void> _pickProfilePhoto() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );

    final file = result?.files.single;
    if (file == null) {
      return;
    }

    setState(() {
      selectedPhotoPath = file.path?.trim().isNotEmpty == true
          ? file.path!.trim()
          : file.name;
      selectedPhotoName = file.name;
    });
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF1E293B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    VoidCallback? onTap,
    bool readOnly = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: _inputDecoration(label),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: value.isEmpty ? null : value,
        dropdownColor: const Color(0xFF1E293B),
        decoration: _inputDecoration(label),
        style: const TextStyle(color: Colors.white),
        items: items
            .map(
              (item) =>
                  DropdownMenuItem<String>(value: item, child: Text(item)),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF14B8A6),
              surface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        dobController.text = '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  UserProfile _buildProfileFromForm() {
    final existing = widget.appState.profile;

    return existing.copyWith(
      prefix: selectedPrefix,
      name: nameController.text.trim(),
      joinAs: selectedJoinAs,
      contactNumber: contactController.text.trim(),
      dob: dobController.text.trim(),
      rollNo: _showAcademicFields ? rollController.text.trim() : '',
      batch: _showAcademicFields ? batchController.text.trim() : '',
      // TODO: Upload this selected file to Firebase Storage when
      // firebase_storage is configured for the project.
      photoUrl: selectedPhotoPath.trim(),
      presentAddress: presentAddressController.text.trim(),
      permanentAddress: permanentAddressController.text.trim(),
      emergencyContactPerson: emergencyPersonController.text.trim(),
      emergencyRelationship: relationshipController.text.trim(),
      emergencyContactNumber: emergencyNumberController.text.trim(),
      bloodGroup: bloodGroupController.text.trim(),
    );
  }

  Future<void> _saveProfile() async {
    setState(() {
      isSaving = true;
    });

    try {
      final updatedProfile = _buildProfileFromForm();
      await widget.appState.saveProfile(updatedProfile);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updatedProfile.isComplete
                ? 'Personal information saved'
                : 'Profile saved. You can complete missing details later.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save profile: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.appState.profile;
    final isComplete = profile.profileCompleted || profile.isComplete;
    final hasSelectedPhoto = selectedPhotoPath.trim().isNotEmpty;
    final selectedScientificAvatar = UserProfile.scientificAvatarFromReference(
      selectedPhotoPath,
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfilePhotoPreview(),
            const SizedBox(height: 10),
            Text(
              isComplete ? 'Profile complete' : 'Personal information optional',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Personal Information'),
            _buildDropdown(
              label: 'Prefix',
              value: selectedPrefix,
              items: _prefixes,
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  selectedPrefix = value;
                });
              },
            ),
            _buildTextField(label: 'Name', controller: nameController),
            _buildDropdown(
              label: 'Join as',
              value: selectedJoinAs,
              items: _joinAsOptions,
              onChanged: (value) {
                setState(() {
                  selectedJoinAs = value ?? '';
                });
              },
            ),
            _buildTextField(
              label: 'Contact number',
              controller: contactController,
              keyboardType: TextInputType.phone,
            ),
            _buildTextField(
              label: 'Date of birth',
              controller: dobController,
              readOnly: true,
              onTap: _selectDate,
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_circle_rounded,
                    color: Color(0xFF14B8A6),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Profile photo or avatar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasSelectedPhoto
                              ? selectedPhotoName
                              : 'Required for profile completion',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedScientificAvatar != null
                              ? 'Built-in scientific avatars work without file upload.'
                              : 'Choose an image now, or pick a built-in scientific avatar below.',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _pickProfilePhoto,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Choose'),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Scientific avatars',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pick a built-in lab-themed avatar instead of uploading a real photo.',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: UserProfile.scientificAvatarOptions.map((option) {
                      final isSelected = selectedPhotoPath.trim() == option.reference;

                      return ChoiceChip(
                        selected: isSelected,
                        showCheckmark: false,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(
                          option.icon,
                          size: 18,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF14B8A6),
                        ),
                        label: Text(option.label),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor: const Color(0xFF0F172A),
                        selectedColor: const Color(0x3314B8A6),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF14B8A6)
                              : Colors.white10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        onSelected: (_) => _selectScientificAvatar(option),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            if (_showAcademicFields) ...[
              _buildTextField(label: 'Roll number', controller: rollController),
              _buildTextField(label: 'Batch', controller: batchController),
            ],
            const SizedBox(height: 8),
            _buildSectionTitle('Optional Extra Details'),
            _buildTextField(
              label: 'Present address',
              controller: presentAddressController,
              maxLines: 2,
            ),
            _buildTextField(
              label: 'Permanent address',
              controller: permanentAddressController,
              maxLines: 2,
            ),
            _buildTextField(
              label: 'Emergency contact person',
              controller: emergencyPersonController,
            ),
            _buildTextField(
              label: 'Relationship',
              controller: relationshipController,
            ),
            _buildTextField(
              label: 'Emergency contact number',
              controller: emergencyNumberController,
              keyboardType: TextInputType.phone,
            ),
            _buildTextField(
              label: 'Blood group',
              controller: bloodGroupController,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14B8A6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Personal Information',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
