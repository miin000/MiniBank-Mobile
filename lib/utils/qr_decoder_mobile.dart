import 'package:mobile_scanner/mobile_scanner.dart';

Future<String?> decodeQrWeb(dynamic bytes) async => null;

Future<String?> decodeQrMobile(String path) async {
  final controller = MobileScannerController();
  final result = await controller.analyzeImage(path);
  await controller.dispose();
  return result?.barcodes.first.rawValue;
}