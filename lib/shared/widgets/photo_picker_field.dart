import 'dart:io';

import 'package:bid_book/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PhotoPickerField extends StatefulWidget {
  const PhotoPickerField({
    required this.files,
    required this.onChanged,
    this.title = 'Add photos',
    this.subtitle = 'Show the work clearly. You can select multiple photos.',
    this.maxImages = 8,
    super.key,
  });

  final List<XFile> files;
  final ValueChanged<List<XFile>> onChanged;
  final String title;
  final String subtitle;
  final int maxImages;

  @override
  State<PhotoPickerField> createState() => _PhotoPickerFieldState();
}

class _PhotoPickerFieldState extends State<PhotoPickerField> {
  final _picker = ImagePicker();
  bool _picking = false;

  Future<void> _gallery() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picked = await _picker.pickMultiImage(
        imageQuality: 82,
        maxWidth: 1920,
        maxHeight: 1920,
        limit: widget.maxImages,
      );
      if (!mounted || picked.isEmpty) return;
      final merged = <XFile>[...widget.files];
      for (final file in picked) {
        if (merged.length >= widget.maxImages) break;
        if (!merged.any((item) => item.path == file.path)) merged.add(file);
      }
      widget.onChanged(merged);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _camera() async {
    if (_picking || widget.files.length >= widget.maxImages) return;
    setState(() => _picking = true);
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 82,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (file != null) widget.onChanged([...widget.files, file]);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.blueSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(widget.subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.files.isNotEmpty) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.files.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final file = widget.files[index];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            File(file.path),
                            width: 92,
                            height: 92,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 5,
                          right: 5,
                          child: InkWell(
                            onTap: () {
                              final next = [...widget.files]..removeAt(index);
                              widget.onChanged(next);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 15, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _picking || widget.files.length >= widget.maxImages ? null : _gallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(_picking ? 'Opening…' : 'Gallery'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _picking || widget.files.length >= widget.maxImages ? null : _camera,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text('${widget.files.length}/${widget.maxImages} photos', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
