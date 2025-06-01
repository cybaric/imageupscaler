import 'dart:io';
import 'package:flutter/foundation.dart'; // Untuk @immutable

@immutable
class UpscalerState {
  final File? originalImageFile;
  final File? upscaledImageFile;
  final bool isLoadingImage; // Untuk proses load image picker
  final bool isProcessing;   // Untuk proses upscale
  final bool isSaving;       // Untuk proses save
  final double progressValue;
  final String? statusMessage;
  final String? errorMessage;

  const UpscalerState({
    this.originalImageFile,
    this.upscaledImageFile,
    this.isLoadingImage = false,
    this.isProcessing = false,
    this.isSaving = false,
    this.progressValue = 0.0,
    this.statusMessage,
    this.errorMessage,
  });

  UpscalerState copyWith({
    File? originalImageFile,
    ValueGetter<File?>? upscaledImageFile, // Gunakan ValueGetter untuk handle null
    bool? isLoadingImage,
    bool? isProcessing,
    bool? isSaving,
    double? progressValue,
    ValueGetter<String?>? statusMessage,
    ValueGetter<String?>? errorMessage,
  }) {
    return UpscalerState(
      originalImageFile: originalImageFile ?? this.originalImageFile,
      upscaledImageFile: upscaledImageFile != null ? upscaledImageFile() : this.upscaledImageFile,
      isLoadingImage: isLoadingImage ?? this.isLoadingImage,
      isProcessing: isProcessing ?? this.isProcessing,
      isSaving: isSaving ?? this.isSaving,
      progressValue: progressValue ?? this.progressValue,
      statusMessage: statusMessage != null ? statusMessage() : this.statusMessage,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

// Helper untuk ValueGetter agar copyWith lebih mudah menangani null
// Jika Anda tidak suka ini, Anda bisa membuat parameter copyWith nullable
// dan secara eksplisit memeriksa `null` vs `Value(null)`
class ValueGetter<T> {
  final T Function() _getter;
  ValueGetter(this._getter);
  T call() => _getter();
}