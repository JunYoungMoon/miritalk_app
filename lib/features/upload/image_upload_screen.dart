import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class ImageUploadScreen extends StatefulWidget {
  const ImageUploadScreen({super.key});

  @override
  State<ImageUploadScreen> createState() => _ImageUploadScreenState();
}

class _ImageUploadScreenState extends State<ImageUploadScreen> {
  static const int maxImages = 5;
  static const String _baseUrl = 'http://YOUR_SERVER_IP:8080';

  final ImagePicker _picker = ImagePicker();
  final List<File> _selectedImages = [];
  bool _isUploading = false;

  Future<void> _pickImage() async {
    if (_selectedImages.length >= maxImages) {
      _showSnackBar('사진은 최대 5장까지 선택 가능합니다.');
      return;
    }

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() => _selectedImages.add(File(image.path)));
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  Future<void> _uploadImages() async {
    if (_selectedImages.isEmpty) {
      _showSnackBar('사진을 먼저 선택해주세요.');
      return;
    }
    if (_selectedImages.length < maxImages) {
      _showSnackBar('사진 5장을 모두 선택해주세요.');
      return;
    }

    setState(() => _isUploading = true);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/fraud/analyze'),
      );

      for (int i = 0; i < _selectedImages.length; i++) {
        request.files.add(await http.MultipartFile.fromPath(
          'images',
          _selectedImages[i].path,
        ));
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        _showSnackBar('업로드 완료! 분석 중입니다.');
      } else {
        _showSnackBar('업로드 실패. 다시 시도해주세요.');
      }
    } catch (e) {
      _showSnackBar('오류가 발생했습니다: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('사진 업로드', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${_selectedImages.length} / $maxImages 장 선택됨',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _selectedImages.length < maxImages
                    ? _selectedImages.length + 1
                    : _selectedImages.length,
                itemBuilder: (context, index) {
                  if (index == _selectedImages.length) {
                    return _AddImageTile(onTap: _pickImage);
                  }
                  return _ImageTile(
                    image: _selectedImages[index],
                    onRemove: () => _removeImage(index),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isUploading ? null : _uploadImages,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4FC3F7),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isUploading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Text(
                '분석 요청하기',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddImageTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddImageTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4FC3F7), width: 1.5),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                color: Color(0xFF4FC3F7), size: 40),
            SizedBox(height: 8),
            Text('사진 추가', style: TextStyle(color: Color(0xFF4FC3F7))),
          ],
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final File image;
  final VoidCallback onRemove;
  const _ImageTile({required this.image, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(image, fit: BoxFit.cover,
              width: double.infinity, height: double.infinity),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
    );
  }
}