import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/user_profile.dart';

class EditProfileScreen extends StatefulWidget {
  final AppState appState;

  const EditProfileScreen({
    super.key,
    required this.appState,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController nameController;
  late final TextEditingController rollController;
  late final TextEditingController batchController;
  late final TextEditingController dobController;
  late final TextEditingController hobbiesController;
  late final TextEditingController aboutController;

  @override
  void initState() {
    super.initState();
    final profile = widget.appState.profile;

    nameController = TextEditingController(text: profile.name);
    rollController = TextEditingController(text: profile.rollNo);
    batchController = TextEditingController(text: profile.batch);
    dobController = TextEditingController(text: profile.dob);
    hobbiesController = TextEditingController(text: profile.hobbies);
    aboutController = TextEditingController(text: profile.about);
  }

  @override
  void dispose() {
    nameController.dispose();
    rollController.dispose();
    batchController.dispose();
    dobController.dispose();
    hobbiesController.dispose();
    aboutController.dispose();
    super.dispose();
  }

  Widget buildTextField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    VoidCallback? onTap,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Future<void> selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1980),
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

  Future<void> saveProfile() async {
    final updatedProfile = UserProfile(
      name: nameController.text.trim(),
      rollNo: rollController.text.trim(),
      batch: batchController.text.trim(),
      dob: dobController.text.trim(),
      hobbies: hobbiesController.text.trim(),
      about: aboutController.text.trim(),
    );

    await widget.appState.saveProfile(updatedProfile);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile saved successfully'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 45,
              backgroundColor: Color(0xFF1E293B),
              child: Icon(
                Icons.person,
                size: 45,
                color: Color(0xFF14B8A6),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.camera_alt, color: Color(0xFF14B8A6)),
              label: const Text(
                'Change Photo',
                style: TextStyle(color: Color(0xFF14B8A6)),
              ),
            ),
            const SizedBox(height: 20),
            buildTextField(label: 'Name', controller: nameController),
            buildTextField(label: 'Roll No', controller: rollController),
            buildTextField(label: 'Batch', controller: batchController),
            buildTextField(
              label: 'Date of Birth',
              controller: dobController,
              readOnly: true,
              onTap: selectDate,
            ),
            buildTextField(label: 'Hobbies', controller: hobbiesController),
            buildTextField(
              label: 'About Yourself',
              controller: aboutController,
              maxLines: 4,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14B8A6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Save Profile',
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