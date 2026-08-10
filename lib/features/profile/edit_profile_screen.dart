// ═════════════════════════════════════════════════════════════════════════════
// V Shots — EditProfileScreen (Nova Profile Editor)
// ═════════════════════════════════════════════════════════════════════════════

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/models/profile_model.dart';
import '../../core/services/profile_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_input.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.initialProfile,
    this.onProfileUpdated,
  });

  final ProfileModel initialProfile;
  final ValueChanged<ProfileModel>? onProfileUpdated;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;

  String? _avatarUrl;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialProfile.fullName);
    _usernameController = TextEditingController(text: widget.initialProfile.username);
    _bioController = TextEditingController(text: widget.initialProfile.bio);
    _avatarUrl = widget.initialProfile.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          final uploadedUrl = await ProfileService.instance.uploadAvatar(
            file.bytes!,
            file.extension ?? 'jpg',
          );
          if (uploadedUrl != null && mounted) {
            setState(() => _avatarUrl = uploadedUrl);
          }
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Could not pick image: $e');
    }
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final bio = _bioController.text.trim();

    if (name.isEmpty || username.isEmpty) {
      setState(() => _errorMessage = 'Name and Username cannot be empty.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final updated = await ProfileService.instance.updateProfile(
      fullName: name,
      username: username,
      bio: bio,
      avatarUrl: _avatarUrl,
    );

    if (mounted) {
      widget.onProfileUpdated?.call(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textMain, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: AppColors.textMain,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar Edit Section
              Center(
                child: Stack(
                  children: [
                    AppAvatar(
                      avatarUrl: _avatarUrl,
                      name: _nameController.text,
                      size: 96,
                      hasGradientBorder: true,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickAvatar,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.primaryGradient,
                            border: Border.all(color: AppColors.surface, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _pickAvatar,
                  child: const Text(
                    'Change Avatar Photo',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Error banner if any
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Form fields
              AppTextInput(
                controller: _nameController,
                label: 'Display Name',
                hintText: 'Your creator name',
                prefixIcon: Icons.badge_outlined,
              ),
              const SizedBox(height: 16),

              AppTextInput(
                controller: _usernameController,
                label: 'Username',
                hintText: 'handle (without @)',
                prefixIcon: Icons.alternate_email_rounded,
              ),
              const SizedBox(height: 16),

              AppTextInput(
                controller: _bioController,
                label: 'Bio',
                hintText: 'Tell the community about yourself...',
                maxLines: 4,
              ),
              const SizedBox(height: 32),

              // Save Button
              AppButton(
                text: 'Save Changes',
                icon: Icons.check_rounded,
                size: AppButtonSize.large,
                isLoading: _isSaving,
                onPressed: _handleSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
