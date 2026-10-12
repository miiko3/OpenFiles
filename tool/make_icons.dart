import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final source = File(r'C:\Users\123\Documents\Default Project\OpenFiles\app_icon.png');
  final original = img.decodeImage(source.readAsBytesSync())!;

  const sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  final res = Directory('android/app/src/main/res');
  for (final entry in sizes.entries) {
    final dir = Directory('${res.path}/${entry.key}');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final resized = img.copyResize(
      original,
      width: entry.value,
      height: entry.value,
      interpolation: img.Interpolation.average,
    );
    File('${dir.path}/ic_launcher.png')
        .writeAsBytesSync(img.encodePng(resized, level: 9));
  }

  File('${res.path}/mipmap-xxxhdpi/ic_launcher@1.5x.png')
      .writeAsBytesSync(
    img.encodePng(
      img.copyResize(original, width: 324, height: 324, interpolation: img.Interpolation.average),
      level: 9,
    ),
  );

  final fg = img.copyResize(original, width: 432, height: 432, interpolation: img.Interpolation.average);
  File('${res.path}/drawable/ic_launcher_foreground.png')
      .writeAsBytesSync(img.encodePng(fg, level: 9));

  final background = img.Image(width: 432, height: 432);
  img.fill(background, color: img.ColorRgba8(222, 161, 131, 255));
  for (var y = 0; y < 432; y++) {
    for (var x = 0; x < 432; x++) {
      final t = (x + y) / 864.0;
      background.setPixelRgba(
        x,
        y,
        (214 + 20 * t).round(),
        (150 + 25 * t).round(),
        (118 + 20 * t).round(),
        255,
      );
    }
  }
  File('${res.path}/drawable/ic_launcher_background.png')
      .writeAsBytesSync(img.encodePng(background, level: 9));

  File('assets/icon.png').writeAsBytesSync(
    img.encodePng(
      img.copyResize(original, width: 512, height: 512, interpolation: img.Interpolation.average),
      level: 9,
    ),
  );

  stdout.writeln('icons written');
}