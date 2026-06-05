export 'qr_decoder_stub.dart'
    if (dart.library.io) 'qr_decoder_mobile.dart'
    if (dart.library.html) 'qr_decoder_web.dart';