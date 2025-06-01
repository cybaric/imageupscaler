import 'dart:io';
import 'dart:async'; // Untuk Future.delayed
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Upscaler',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF2D2D2D),
        cardTheme: CardThemeData(
          color: const Color(0xFF3C3C3C),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurpleAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Colors.deepPurpleAccent,
          linearTrackColor: Color(0xFF555555),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white70),
          bodyMedium: TextStyle(color: Colors.white60),
          titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      home: const UpscalerPage(),
    );
  }
}

class UpscalerPage extends StatefulWidget {
  const UpscalerPage({super.key});

  @override
  State<UpscalerPage> createState() => _UpscalerPageState();
}

class _UpscalerPageState extends State<UpscalerPage> {
  File? _originalImageFile;
  File? _upscaledImageFile;
  bool _isProcessing = false;
  double _progressValue = 0.0;
  String _statusMessage = "";

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      // Untuk Android 13+ dan iOS, gunakan Permission.photos
      // Untuk Android < 13, Permission.storage masih relevan
      // Permission.manageExternalStorage mungkin diperlukan untuk akses yang lebih luas di Android 11+
      // tapi biasanya tidak diperlukan hanya untuk menyimpan ke galeri umum.
      Permission.photos,
      Permission.storage, // Untuk kompatibilitas dengan Android versi lama
      Permission.camera,
    ].request();

    if ((statuses[Permission.photos]!.isDenied || statuses[Permission.photos]!.isPermanentlyDenied) &&
        (statuses[Permission.storage]!.isDenied || statuses[Permission.storage]!.isPermanentlyDenied)) {
      _showSnackBar("Izin galeri/penyimpanan ditolak. Fitur simpan dan pilih gambar mungkin tidak berfungsi.");
      // Anda bisa membuka pengaturan aplikasi di sini jika izin ditolak permanen
      // if (await Permission.photos.isPermanentlyDenied || await Permission.storage.isPermanentlyDenied) {
      //   openAppSettings();
      // }
    }
  }


  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _pickImage() async {
    if (_isProcessing) return;
    try {
      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _originalImageFile = File(pickedFile.path);
          _upscaledImageFile = null;
          _statusMessage = "Gambar berhasil dimuat.";
        });
      } else {
        _statusMessage = "Tidak ada gambar yang dipilih.";
      }
    } catch (e) {
      _statusMessage = "Error saat memilih gambar: $e";
      _showSnackBar(_statusMessage);
    }
    setState(() {});
  }

  Future<void> _upscaleImage() async {
    if (_originalImageFile == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _progressValue = 0.0;
      _upscaledImageFile = null;
      _statusMessage = "Memproses gambar...";
    });

    for (int i = 0; i <= 100; i += 5) {
      await Future.delayed(const Duration(milliseconds: 150));
      setState(() {
        _progressValue = i / 100.0;
      });
    }

    if (_originalImageFile != null) {
       _upscaledImageFile = _originalImageFile; // Placeholder, ganti dengan hasil model ESRGAN
    }

    setState(() {
      _isProcessing = false;
      _statusMessage = _upscaledImageFile != null ? "Gambar berhasil di-upscale!" : "Gagal melakukan upscale.";
    });
  }

  Future<void> _saveImage() async {
    if (_upscaledImageFile == null || _isProcessing) return;

    setState(() {
      _statusMessage = "Menyimpan gambar...";
    });

    try {
      // Cek izin lagi sebelum menyimpan, meskipun sudah diminta di initState
      bool photosPermissionGranted = await Permission.photos.isGranted || await Permission.photos.isLimited; // iOS & Android 13+
      bool storagePermissionGranted = await Permission.storage.isGranted; // Android < 13

      bool canSave = false;
      if (Platform.isIOS) {
        canSave = photosPermissionGranted;
      } else { // Android
        // Untuk Android, kita perlu sedikit lebih detail
        // Android SDK version bisa didapatkan jika perlu, tapi biasanya permission handler cukup
        // Untuk tujuan umum menyimpan ke galeri:
        // Jika photos (READ_MEDIA_IMAGES) granted, itu bagus untuk Android 13+
        // Jika storage (WRITE_EXTERNAL_STORAGE) granted, itu bagus untuk < 13
        canSave = photosPermissionGranted || storagePermissionGranted;
      }

      if (!canSave) {
        _showSnackBar("Izin penyimpanan belum diberikan. Silakan berikan izin melalui pengaturan aplikasi.");
        await _requestPermissions(); // Coba minta lagi jika belum
        // Cek ulang setelah meminta
        photosPermissionGranted = await Permission.photos.isGranted || await Permission.photos.isLimited;
        storagePermissionGranted = await Permission.storage.isGranted;
        if (Platform.isIOS) {
          canSave = photosPermissionGranted;
        } else {
          canSave = photosPermissionGranted || storagePermissionGranted;
        }

        if (!canSave) {
          setState(() {
            _statusMessage = "Gagal menyimpan: Izin ditolak.";
          });
          return;
        }
      }

      // Menggunakan ImageGallerySaverPlus
      final result = await ImageGallerySaverPlus.saveFile(_upscaledImageFile!.path);

      // image_gallery_saver_plus mengembalikan Map<dynamic, dynamic> atau null
      // 'isSuccess' dan 'filePath' adalah key yang umum digunakan oleh plugin sejenis
      if (result != null && result['isSuccess'] == true) {
        _statusMessage = "Gambar berhasil disimpan ke galeri! Path: ${result['filePath'] ?? ''}";
        _showSnackBar(_statusMessage);
      } else {
        _statusMessage = "Gagal menyimpan gambar. Error: ${result?['errorMessage'] ?? 'Unknown error'}";
        _showSnackBar(_statusMessage);
      }
    } catch (e) {
      _statusMessage = "Error saat menyimpan gambar: $e";
      _showSnackBar(_statusMessage);
    }
    setState(() {});
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: message.toLowerCase().contains("gagal") || message.toLowerCase().contains("error")
            ? Colors.redAccent
            : Colors.green,
      ),
    );
  }

  Widget _buildImagePlaceholder(String text) {
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
            Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.white54),
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }

  Widget _buildImageDisplay(File? imageFile, {bool isOriginal = true}) {
    if (imageFile == null) {
      return _buildImagePlaceholder(isOriginal ? "Belum ada gambar sumber" : "Hasil upscale akan tampil di sini");
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: 300,
        ),
        child: Image.file(
          imageFile,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _buildImagePlaceholder("Gagal memuat gambar");
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESRGAN Image Upscaler'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ElevatedButton.icon(
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Load Image'),
              onPressed: _isProcessing ? null : _pickImage,
            ),
            const SizedBox(height: 20),

            Text('Original Image:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildImageDisplay(_originalImageFile, isOriginal: true),
            const SizedBox(height: 20),

            if (_originalImageFile != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.zoom_in_map_outlined),
                label: const Text('Upscale Image'),
                onPressed: _isProcessing ? null : _upscaleImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isProcessing ? Colors.grey : Colors.greenAccent.shade700,
                ),
              ),
            const SizedBox(height: 10),

            if (_isProcessing)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: _progressValue,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Processing... ${(_progressValue * 100).toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),

            if (_statusMessage.isNotEmpty && !_isProcessing)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _statusMessage.toLowerCase().contains("gagal") || _statusMessage.toLowerCase().contains("error")
                        ? Colors.redAccent
                        : Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            const SizedBox(height: 10),
            Text('Upscaled Image:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildImageDisplay(_upscaledImageFile, isOriginal: false),
            const SizedBox(height: 20),

            if (_upscaledImageFile != null && !_isProcessing)
              ElevatedButton.icon(
                icon: const Icon(Icons.save_alt_outlined),
                label: const Text('Save Upscaled Image'),
                onPressed: _saveImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                ),
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}