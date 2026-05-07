import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:minibank/utils/qr_decoder_mobile.dart';
import 'package:minibank/utils/qr_decoder_web.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _handled = false;
  bool _pickingImage = false;
  String? _pickError;

  Future<void> _pickFromGallery() async {
    if (_pickingImage) return;
    setState(() {
      _pickingImage = true;
      _pickError = null;
    });

    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null || !mounted) return;

      String? raw;

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        raw = await decodeQrWeb(bytes); 
      } else {
        raw = await decodeQrMobile(file.path);
      }

      if (!mounted) return;

      if (raw == null || raw.isEmpty) {
        setState(() => _pickError = 'Không tìm thấy mã QR trong ảnh');
        return;
      }

      if (_handled) return;
      _handled = true;
      Navigator.of(context).pop(raw);
    } catch (e) {
      if (!mounted) return;
      setState(() => _pickError = 'Lỗi đọc ảnh: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét QR'),
        actions: [
          if (_pickingImage)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.photo_library_outlined),
              tooltip: 'Chọn ảnh từ thư viện',
              onPressed: _pickFromGallery,
            ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_handled) return;
              final codes = capture.barcodes;
              if (codes.isEmpty) return;
              final raw = codes.first.rawValue;
              if (raw == null || raw.isEmpty) return;
              _handled = true;
              Navigator.of(context).pop(raw);
            },
          ),
          // Scan frame overlay
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Error banner
          if (_pickError != null)
            Positioned(
              bottom: 32,
              left: 24,
              right: 24,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _pickError!,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _pickError = null),
                        child: const Icon(Icons.close, color: Colors.white54, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}