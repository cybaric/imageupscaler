import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/upscaler_providers.dart';
import '../application/upscaler_state.dart'; // Untuk akses state langsung jika perlu

class UpscalerPage extends ConsumerWidget {
  const UpscalerPage({super.key});

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar(); // Hapus snackbar lama
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  Widget _buildImagePlaceholder(String text, ThemeData theme) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined, size: 48, color: theme.iconTheme.color?.withValues(alpha: 0.7)),
            const SizedBox(height: 8),
            Text(text, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildImageDisplay(File? imageFile, String placeholderText, ThemeData theme) {
    if (imageFile == null) {
      return _buildImagePlaceholder(placeholderText, theme);
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300),
        child: Image.file(
          imageFile,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _buildImagePlaceholder("Gagal memuat gambar", theme);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final upscalerState = ref.watch(upscalerNotifierProvider);
    final upscalerNotifier = ref.read(upscalerNotifierProvider.notifier);

    // Listener untuk menampilkan snackbar berdasarkan errorMessage atau statusMessage tertentu
    ref.listen<UpscalerState>(upscalerNotifierProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        _showSnackBar(context, next.errorMessage!, isError: true);
      } else if (next.statusMessage != null &&
                 next.statusMessage != previous?.statusMessage &&
                 (next.statusMessage!.toLowerCase().contains("berhasil disimpan") ||
                  next.statusMessage!.toLowerCase().contains("gagal menyimpan gambar") // Tambahkan kondisi lain jika perlu
                 )) {
        _showSnackBar(context, next.statusMessage!, isError: next.statusMessage!.toLowerCase().contains("gagal"));
      }
    });


    final bool canInteract = !upscalerState.isProcessing && !upscalerState.isLoadingImage && !upscalerState.isSaving;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ESRGAN Upscaler (Riverpod)'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ElevatedButton.icon(
              icon: upscalerState.isLoadingImage
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.photo_library_outlined),
              label: Text(upscalerState.isLoadingImage ? 'Loading...' : 'Load Image'),
              onPressed: canInteract ? upscalerNotifier.pickImage : null,
            ),
            const SizedBox(height: 20),

            Text('Original Image:', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildImageDisplay(upscalerState.originalImageFile, "Belum ada gambar sumber", theme),
            const SizedBox(height: 20),

            if (upscalerState.originalImageFile != null)
              ElevatedButton.icon(
                icon: upscalerState.isProcessing
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.zoom_in_map_outlined),
                label: Text(upscalerState.isProcessing ? 'Processing...' : 'Upscale Image'),
                onPressed: canInteract ? upscalerNotifier.upscaleImage : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: upscalerState.isProcessing ? Colors.grey : Colors.greenAccent.shade700,
                ),
              ),
            const SizedBox(height: 10),

            if (upscalerState.isProcessing)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: upscalerState.progressValue,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Processing... ${ (upscalerState.progressValue * 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),

            // Menampilkan status message non-error (jika ada dan tidak sedang proses)
            if (upscalerState.statusMessage != null && !upscalerState.isProcessing && !upscalerState.isSaving && !upscalerState.isLoadingImage && upscalerState.errorMessage == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  upscalerState.statusMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: upscalerState.statusMessage!.toLowerCase().contains("gagal")
                        ? Colors.redAccent
                        : Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),


            const SizedBox(height: 10),
            Text('Upscaled Image:', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildImageDisplay(upscalerState.upscaledImageFile, "Hasil upscale akan tampil di sini", theme),
            const SizedBox(height: 20),

            if (upscalerState.upscaledImageFile != null && !upscalerState.isProcessing)
              ElevatedButton.icon(
                icon: upscalerState.isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_alt_outlined),
                label: Text(upscalerState.isSaving ? 'Saving...' : 'Save Upscaled Image'),
                onPressed: canInteract ? upscalerNotifier.saveImage : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: upscalerState.isSaving ? Colors.grey : Colors.blueAccent,
                ),
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}