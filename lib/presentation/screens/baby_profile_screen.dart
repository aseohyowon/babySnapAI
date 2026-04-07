import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/entities/baby_profile.dart';
import '../../domain/entities/gallery_image.dart';
import '../viewmodels/gallery_view_model.dart';

/// Registers a new child profile OR adds a reference photo to an existing one.
///
/// - Pass [existingProfile] = null  →  create new profile (pick photo + name)
/// - Pass [existingProfile] non-null →  add another reference photo to that profile
class BabyProfileScreen extends StatefulWidget {
  const BabyProfileScreen({
    super.key,
    required this.viewModel,
    this.existingProfile,
  });

  final GalleryViewModel viewModel;
  /// Non-null when adding more photos to an already-registered profile.
  final BabyProfile? existingProfile;

  @override
  State<BabyProfileScreen> createState() => _BabyProfileScreenState();
}

class _BabyProfileScreenState extends State<BabyProfileScreen> {
  GalleryImage? _selectedImage;
  final TextEditingController _nameController = TextEditingController();
  bool _isSaving = false;
  String? _error;
  DateTime? _birthDate;

  bool get _addMode => widget.existingProfile != null;

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now().subtract(const Duration(days: 180)),
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
      helpText: '아이 생일을 선택하세요',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF6366F1),
            onPrimary: Colors.white,
            surface: Color(0xFF1E293B),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedImage == null) {
      setState(() => _error = '사진을 선택해 주세요.');
      return;
    }

    if (!_addMode) {
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        setState(() => _error = '이름을 입력해 주세요.');
        return;
      }
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    if (_addMode) {
      // Add photo to existing profile
      final errMsg = await widget.viewModel.addPhotoToProfile(
        widget.existingProfile!,
        _selectedImage!.path,
      );
      if (!mounted) return;
      if (errMsg != null) {
        setState(() {
          _isSaving = false;
          _error = errMsg;
        });
      } else {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${widget.existingProfile!.name} 프로필에 사진이 추가되었습니다.'),
            backgroundColor: const Color(0xFF6366F1),
          ),
        );
      }
    } else {
      // Register new profile
      final faceVector = await widget.viewModel.extractFaceVectorFromImage(
        _selectedImage!.path,
      );
      if (!mounted) return;
      if (faceVector == null) {
        setState(() {
          _isSaving = false;
          _error = '얼굴을 인식할 수 없습니다. 더 선명한 사진을 선택해 주세요.';
        });
        return;
      }
      final profile = BabyProfile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        referencePhotoPath: _selectedImage!.path,
        faceVectors: [faceVector],
        birthDate: _birthDate,
      );
      await widget.viewModel.addProfile(profile);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${profile.name} 프로필이 등록되었습니다.'),
            backgroundColor: const Color(0xFF6366F1),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.viewModel.images;
    final appBarTitle = _addMode
        ? '${widget.existingProfile!.name} 사진 추가'
        : (_selectedImage == null ? '사진 선택' : '아이 프로필 등록');

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Text(appBarTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_selectedImage != null)
            TextButton(
              onPressed: () => setState(() => _selectedImage = null),
              child: const Text('다시 선택',
                  style: TextStyle(color: Color(0xFF818CF8))),
            ),
        ],
      ),
      body: _selectedImage == null
          ? _buildPhotoGrid(images)
          : _buildConfirmStep(),
    );
  }

  Widget _buildPhotoGrid(List<GalleryImage> images) {
    if (images.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, color: Colors.white38, size: 64),
            SizedBox(height: 16),
            Text(
              '스캔된 사진이 없습니다.\n먼저 갤러리를 스캔해 주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
          ),
          child: const Row(
            children: [
              Icon(Icons.tips_and_updates_outlined,
                  color: Color(0xFF818CF8), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '얼굴이 정면으로 잘 보이는 사진을 선택하면 인식률이 높아집니다.\n'
                  '각도가 다른 사진을 여러 장 추가할수록 더 잘 찾습니다.',
                  style: TextStyle(color: Color(0xFF818CF8), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: images.length,
            itemBuilder: (context, index) {
              final image = images[index];
              return GestureDetector(
                onTap: () => setState(() => _selectedImage = image),
                child: Image.file(
                  File(image.path),
                  fit: BoxFit.cover,
                  cacheWidth: 300,
                  errorBuilder: (_, __, ___) =>
                      Container(color: const Color(0xFF1E293B)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          CircleAvatar(
            radius: 72,
            backgroundImage: FileImage(File(_selectedImage!.path)),
            backgroundColor: const Color(0xFF1E293B),
          ),
          const SizedBox(height: 32),
          if (!_addMode) ...[
            TextField(
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '아이 이름',
                labelStyle: const TextStyle(color: Color(0xFF818CF8)),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF6366F1), width: 2),
                ),
                prefixIcon:
                    const Icon(Icons.child_care, color: Color(0xFF818CF8)),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            // Birth date picker (optional — improves timeline age labels)
            GestureDetector(
              onTap: _pickBirthDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cake_outlined, color: Color(0xFF818CF8), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _birthDate == null
                            ? '생일 입력 (선택사항 — 타임라인 나이 표시용)'
                            : '생일: ${_birthDate!.year}년 ${_birthDate!.month}월 ${_birthDate!.day}일',
                        style: TextStyle(
                          color: _birthDate == null
                              ? const Color(0xFF818CF8)
                              : Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (_birthDate != null)
                      GestureDetector(
                        onTap: () => setState(() => _birthDate = null),
                        child: const Icon(Icons.close, color: Colors.white38, size: 18),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (_addMode)
            Text(
              '이 사진을 ${widget.existingProfile!.name} 프로필에 추가합니다',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _addMode ? '사진 추가' : '프로필 등록',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
