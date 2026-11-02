import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:bojian_native_layout/native_layout.dart';

@JS('bojianPayload') external JSString get payload;
@JS('bojianComplete') external void complete(JSString output);
@JS('bojianFailure') external void failure(JSString message);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  NativeLayoutRenderer? renderer;
  NativeDocument? document;
  try {
    final input = jsonDecode(payload.toDart) as Map;
    final native = input['native'] as Map;
    final layout = Map<String,dynamic>.from(native['layout'] as Map);
    validateNativeLayout(layout);
    final fields = Map<String,dynamic>.from(input['fields'] as Map);
    final photo = fields['photo_png'] as String?;
    renderer = NativeLayoutRenderer(layout, fields, {
      for(final e in (native['assets'] as Map).entries) e.key as String: base64Decode(e.value as String),
    }, photoBytes: photo == null || photo.isEmpty ? null : base64Decode(photo));
    await NativeLayoutRenderer.loadFonts(rootBundle);
    await renderer.prepare();
    document = renderer.buildDocument();
    final pages = <String>[];
    for(final page in document.pages) {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)..scale(1.5);
      canvas.drawPicture(page);
      final picture = recorder.endRecording();
      final image = await picture.toImage((document.size.width*1.5).round(), (document.size.height*1.5).round());
      picture.dispose();
      try {
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        pages.add(base64Encode(bytes.buffer.asUint8List(bytes.offsetInBytes,bytes.lengthInBytes)));
      } finally { image.dispose(); }
    }
    complete(jsonEncode({'pages':pages,'count':pages.length,'renderer':'native-layout-v1-20261031'}).toJS);
  } catch(e) { failure(e.toString().toJS); }
  finally { document?.dispose();renderer?.dispose(); }
}
