import 'dart:io';

void main() {
  final file = File('lib/features/sheet/sheet_codec.dart');
  final lines = file.readAsLinesSync();
  var changed = false;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].contains("'s': ''") && lines[i].contains('if (style != null)')) {
      lines[i] = "      if (style != null) 's': '\$style',";
      changed = true;
    }
  }
  file.writeAsStringSync(lines.join('\n'));
  stdout.writeln(changed ? 'fixed' : 'not found');
}