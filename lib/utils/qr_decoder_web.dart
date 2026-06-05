import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:web/web.dart';

@JS('jsQR')
external JSObject? _jsQR(JSUint8ClampedArray data, int width, int height);

Future<String?> decodeQrMobile(String path) async => null;

Future<String?> decodeQrWeb(Uint8List bytes) async {
  // Dùng Canvas để decode image bytes -> pixel data
  final blob = Blob([bytes.toJS].toJS);
  final url = URL.createObjectURL(blob);

  final img = HTMLImageElement();
  img.src = url;
  await img.onLoad.first;

  final canvas = HTMLCanvasElement()
    ..width = img.naturalWidth
    ..height = img.naturalHeight;
  final ctx = canvas.getContext('2d') as CanvasRenderingContext2D;
  ctx.drawImage(img, 0, 0);

  URL.revokeObjectURL(url);

  final imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
  final result = _jsQR(imageData.data, canvas.width, canvas.height);
  if (result == null) return null;

  return (result as JSObject).getProperty('data'.toJS).toString();
}