import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

Future<String?> decodeQrMobile(String path) async {
  final controller = MobileScannerController();
  final result = await controller.analyzeImage(path);
  await controller.dispose();
  return result?.barcodes.first.rawValue;
}