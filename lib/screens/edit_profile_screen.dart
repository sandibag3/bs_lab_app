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
    selectedPhotoName = _fileNameFromPath(profile.photoUrl);
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

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 45,
              backgroundColor: const Color(0xFF1E293B),
              child: !hasSelectedPhoto
                  ? const Icon(Icons.person, size: 45, color: Color(0xFF14B8A6))
                  : const Icon(
                      Icons.image_rounded,
                      size: 42,
                      color: Color(0xFF14B8A6),
                    ),
            ),
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
                  const Icon(Icons.image_rounded, color: Color(0xFF14B8A6)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Profile photo',
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
                        const Text(
                          'Storage upload TODO: Firebase Storage is not configured.',
                          style: TextStyle(
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
