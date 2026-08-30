import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:svnly/features/profile/edit_profile_screen.dart';

void main() {
  test(
    'avatar preparation center-crops, resizes and encodes a bounded JPEG',
    () {
      final source = image.Image(width: 1200, height: 800);
      image.fill(source, color: image.ColorRgb8(255, 61, 154));
      final output = prepareAvatarImage(
        Uint8List.fromList(image.encodePng(source)),
      );
      final decoded = image.decodeJpg(output);

      expect(decoded, isNotNull);
      expect(decoded!.width, 768);
      expect(decoded.height, 768);
      expect(output.lengthInBytes, lessThan(5 * 1024 * 1024));
    },
  );
}
