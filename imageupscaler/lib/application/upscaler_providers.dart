import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'upscaler_notifier.dart';
import 'upscaler_state.dart';

final upscalerNotifierProvider = StateNotifierProvider<UpscalerNotifier, UpscalerState>((ref) {
  return UpscalerNotifier();
});