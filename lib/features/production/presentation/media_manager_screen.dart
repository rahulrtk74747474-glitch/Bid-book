import 'package:bid_book/core/api/api_exception.dart';
import 'package:bid_book/features/production/application/media_uploader.dart';
import 'package:bid_book/features/production/data/production_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class MediaManagerScreen extends ConsumerStatefulWidget {
  const MediaManagerScreen({
    required this.entityType,
    required this.entityId,
    super.key,
  });

  final String entityType;
  final String entityId;

  @override
  ConsumerState<MediaManagerScreen> createState() => _MediaManagerScreenState();
}

class _MediaManagerScreenState extends ConsumerState<MediaManagerScreen> {
  bool _loading = true;
  bool _uploading = false;
  Object? _error;
  List<Map<String, dynamic>> _media = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final media = await ref.read(productionApiProvider).media(
            entityType: widget.entityType,
            entityId: widget.entityId,
          );
      if (mounted) setState(() => _media = media);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUpload(String kind) async {
    if (_uploading) return;
    final uploader = MediaUploader(ref.read(productionApiProvider));
    try {
      PickedBidBookFile? selected;
      if (kind == 'camera') {
        selected = await uploader.pickPhoto(source: ImageSource.camera);
      } else if (kind == 'gallery') {
        selected = await uploader.pickPhoto();
      } else {
        selected = await uploader.pickEvidenceDocument();
      }
      if (selected == null || !mounted) return;
      setState(() => _uploading = true);
      await uploader.upload(
        entityType: widget.entityType,
        entityId: widget.entityId,
        file: selected,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File uploaded and verified.')),
        );
      }
    } catch (error) {
      if (mounted) {
        final message = error is ApiException ? error.message : error.toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      uploader.dispose();
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photos & documents')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const Text(
              'Files are uploaded directly to object storage using short-lived upload URLs. Bid&Book verifies the object before marking it ready.',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _uploading ? null : () => _pickAndUpload('gallery'),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose photo'),
                ),
                OutlinedButton.icon(
                  onPressed: _uploading ? null : () => _pickAndUpload('camera'),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Take photo'),
                ),
                OutlinedButton.icon(
                  onPressed: _uploading ? null : () => _pickAndUpload('document'),
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Photo / PDF'),
                ),
              ],
            ),
            if (_uploading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 20),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Text(
                _error is ApiException ? (_error as ApiException).message : _error.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (_media.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('No files uploaded yet.'),
                ),
              )
            else
              ..._media.map(
                (item) => Card(
                  child: ListTile(
                    leading: Icon(
                      '${item['content_type']}'.startsWith('image/')
                          ? Icons.image_outlined
                          : Icons.picture_as_pdf_outlined,
                    ),
                    title: Text('${item['content_type'] ?? 'File'}'),
                    subtitle: Text(
                      '${item['status'] ?? 'unknown'} • ${_formatBytes((item['size_bytes'] as num?)?.toInt() ?? 0)}',
                    ),
                    trailing: item['status'] == 'ready'
                        ? const Icon(Icons.verified_outlined)
                        : const Icon(Icons.hourglass_empty),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _formatBytes(int value) {
  if (value >= 1024 * 1024) return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  if (value >= 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
  return '$value B';
}
