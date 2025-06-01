import 'dart:io';
import 'dart:isolate';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:imageupscaler/infrastrukture/image_processor.dart';
import 'package:permission_handler/permission_handler.dart';
import 'upscaler_state.dart';


class UpscalerNotifier extends StateNotifier<UpscalerState> {
  UpscalerNotifier() : super(const UpscalerState());

  Isolate? _processingIsolate;
  ReceivePort? _receivePort;

  Future<void> _requestPermissions(List<Permission> permissions) async {
    Map<Permission, PermissionStatus> statuses = await permissions.request();
    statuses.forEach((permission, status) {
      if (status.isDenied || status.isPermanentlyDenied) {
        // Handle denied permissions, mungkin tampilkan pesan
        state = state.copyWith(
          errorMessage: ValueGetter(() => 'Izin ${permission.toString()} ditolak.'),
        );
      }
    });
  }

  Future<void> pickImage() async {
    state = state.copyWith(isLoadingImage: true, statusMessage: ValueGetter(() => null), errorMessage: ValueGetter(() => null));
    try {
      await _requestPermissions([Permission.photos, Permission.storage]); // Minta izin dulu

      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        state = state.copyWith(
          originalImageFile: File(pickedFile.path),
          upscaledImageFile: ValueGetter(() => null), // Reset upscaled image
          statusMessage: ValueGetter(() => 'Gambar berhasil dimuat.'),
          isLoadingImage: false,
        );
      } else {
        state = state.copyWith(
          statusMessage: ValueGetter(() => 'Tidak ada gambar yang dipilih.'),
          isLoadingImage: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        errorMessage: ValueGetter(() => 'Error saat memilih gambar: $e'),
        isLoadingImage: false,
      );
    }
  }

  Future<void> upscaleImage() async {
    if (state.originalImageFile == null || state.isProcessing) return;

    state = state.copyWith(
      isProcessing: true,
      progressValue: 0.0,
      upscaledImageFile: ValueGetter(() => null),
      statusMessage: ValueGetter(() => 'Memulai proses upscale...'),
      errorMessage: ValueGetter(() => null),
    );

    _receivePort = ReceivePort();
    try {
      _processingIsolate = await Isolate.spawn(
        upscaleImageInIsolate,
        ProcessRequest(_receivePort!.sendPort, state.originalImageFile!.path),
      );

      _receivePort!.listen((message) {
        if (message is IsolateMessage) {
          if (message.type == 'progress') {
            state = state.copyWith(progressValue: message.data as double);
          } else if (message.type == 'result') {
            state = state.copyWith(
              upscaledImageFile: ValueGetter(() => File(message.data as String)),
              isProcessing: false,
              progressValue: 1.0,
              statusMessage: ValueGetter(() => 'Gambar berhasil di-upscale!'),
            );
            _stopIsolate();
          } else if (message.type == 'error') {
            state = state.copyWith(
              isProcessing: false,
              errorMessage: ValueGetter(() => message.data as String),
              statusMessage: ValueGetter(() => 'Gagal melakukan upscale.'),
            );
            _stopIsolate();
          }
        }
      });
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: ValueGetter(() => 'Gagal memulai isolate: $e'),
        statusMessage: ValueGetter(() => 'Gagal melakukan upscale.'),
      );
      _stopIsolate();
    }
  }

  void _stopIsolate() {
    _receivePort?.close();
    _processingIsolate?.kill(priority: Isolate.immediate);
    _receivePort = null;
    _processingIsolate = null;
  }

  Future<void> saveImage() async {
    if (state.upscaledImageFile == null || state.isSaving) return;

    state = state.copyWith(isSaving: true, statusMessage: ValueGetter(() => 'Menyimpan gambar...'), errorMessage: ValueGetter(() => null));
    try {
      await _requestPermissions([Permission.photos, Permission.storage]); // Minta izin lagi jika perlu

      final result = await ImageGallerySaverPlus.saveFile(state.upscaledImageFile!.path);
      if (result != null && result['isSuccess'] == true) {
        state = state.copyWith(
          isSaving: false,
          statusMessage: ValueGetter(() => 'Gambar berhasil disimpan! Path: ${result['filePath'] ?? ''}'),
        );
      } else {
        state = state.copyWith(
          isSaving: false,
          statusMessage: ValueGetter(() => 'Gagal menyimpan gambar.'),
          errorMessage: ValueGetter(() => result?['errorMessage']?.toString() ?? 'Unknown error during save'),
        );
      }
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: ValueGetter(() => 'Error saat menyimpan gambar: $e'),
      );
    }
  }

  @override
  void dispose() {
    _stopIsolate(); // Pastikan isolate dihentikan saat notifier di-dispose
    super.dispose();
  }
}