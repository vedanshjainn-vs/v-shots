// ═════════════════════════════════════════════════════════════════════════════
// V Shots — UploadShotScreen (Nova Create & Upload Flow)
// ═════════════════════════════════════════════════════════════════════════════

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/services/shots_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_input.dart';
import '../../shared/widgets/upload_progress_card.dart';

class UploadShotScreen extends StatefulWidget {
  const UploadShotScreen({super.key, this.onUploadComplete});

  final VoidCallback? onUploadComplete;

  @override
  State<UploadShotScreen> createState() => _UploadShotScreenState();
}

class _UploadShotScreenState extends State<UploadShotScreen> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  PlatformFile? _selectedFile;
  String _visibility = 'public';
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _errorMessage;

  @override
  void dispose() {
    _captionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mov', 'avi', 'mkv', 'mp3', 'm4a', 'wav'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not select media file: ${e.toString()}';
      });
    }
  }

  Future<void> _handleUpload() async {
    final caption = _captionController.text.trim();
    if (caption.isEmpty) {
      setState(() => _errorMessage = 'Please provide a caption for your shot.');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.15;
      _errorMessage = null;
    });

    try {
      const videoUrl =
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';
      const thumbnailUrl =
          'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=800&q=80';

      if (_selectedFile?.bytes != null) {
        setState(() => _uploadProgress = 0.45);
        final uploaded = await ShotsService.instance.uploadShotMedia(
          bytes: _selectedFile!.bytes!,
          fileExtension: _selectedFile!.extension ?? 'mp4',
        );
        if (uploaded != null) {
          // Upload successful
        }
      }

      setState(() => _uploadProgress = 0.85);

      final tags = _tagsController.text
          .split(',')
          .map((e) => e.replaceAll('#', '').trim())
          .where((e) => e.isNotEmpty)
          .toList();

      await ShotsService.instance.createShot(
        caption: caption,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        durationSeconds: 18,
        visibility: _visibility,
        tags: tags,
      );

      setState(() => _uploadProgress = 1.0);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚀 Shot published to V Shots!'),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onUploadComplete?.call();
        await Navigator.of(context).maybePop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Upload failed: ${e.toString()}';
          _isUploading = false;
        });
      }
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
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textMain,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Create Shot',
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Media Picker Box
              GestureDetector(
                onTap: _isUploading ? null : _pickMedia,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedFile != null
                          ? AppColors.accent
                          : AppColors.border,
                      width: 1.5,
                    ),
                    gradient: AppColors.cardGradient,
                  ),
                  child: _selectedFile != null
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.accent.withValues(
                                      alpha: 0.15,
                                    ),
                                    border: Border.all(
                                      color: AppColors.accent,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.check_circle_outline_rounded,
                                    color: AppColors.accent,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Text(
                                    _selectedFile!.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textMain,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(_selectedFile!.size / (1024 * 1024)).toStringAsFixed(2)} MB • Tap to replace',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.surfaceElevated,
                                border: Border.all(
                                  color: AppColors.border,
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.video_library_rounded,
                                color: AppColors.accent,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Select Video or Audio Shot',
                              style: TextStyle(
                                color: AppColors.textMain,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'MP4, MOV, MP3, WAV up to 100MB',
                              style: TextStyle(
                                color: AppColors.textSubtle,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Upload progress card if active
              if (_isUploading) ...[
                UploadProgressCard(
                  progress: _uploadProgress,
                  caption: _captionController.text,
                ),
                const SizedBox(height: 16),
              ],

              // Error banner if any
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Caption Input
              AppTextInput(
                controller: _captionController,
                label: 'Caption',
                hintText:
                    'What is happening in this shot? Add hashtags #vshots...',
                maxLines: 4,
              ),
              const SizedBox(height: 16),

              // Tags Input
              AppTextInput(
                controller: _tagsController,
                label: 'Tags / Categories',
                hintText: 'music, dance, synthwave, vibe (comma-separated)',
                prefixIcon: Icons.tag_rounded,
              ),
              const SizedBox(height: 20),

              // Visibility Selector
              const Text(
                'Who can view this Shot?',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildVisibilityOption(
                    'public',
                    'Public',
                    Icons.public_rounded,
                  ),
                  const SizedBox(width: 10),
                  _buildVisibilityOption(
                    'followers',
                    'Followers',
                    Icons.group_rounded,
                  ),
                  const SizedBox(width: 10),
                  _buildVisibilityOption(
                    'private',
                    'Only Me',
                    Icons.lock_outline_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Publish Button
              AppButton(
                text: 'Publish Shot',
                icon: Icons.rocket_launch_rounded,
                size: AppButtonSize.large,
                isLoading: _isUploading,
                onPressed: _isUploading ? null : _handleUpload,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisibilityOption(String value, String label, IconData icon) {
    final isSelected = _visibility == value;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _visibility = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.accent : AppColors.textMuted,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.textMain : AppColors.textSubtle,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
