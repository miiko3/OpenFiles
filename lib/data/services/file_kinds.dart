import 'package:flutter/material.dart';
enum FileKind {
  word,
  sheet,
  slides,
  pdf,
  text,
  markdown,
  csv,
  code,
  image,
  archive,
  ebook,
  font,
  binary,
}
extension FileKindX on FileKind {
  bool get isEditable => const {
        FileKind.word,
        FileKind.sheet,
        FileKind.slides,
        FileKind.text,
        FileKind.markdown,
        FileKind.csv,
        FileKind.code,
      }.contains(this);
  bool get isDocument => const {
        FileKind.word,
        FileKind.sheet,
        FileKind.slides,
        FileKind.pdf,
        FileKind.ebook,
      }.contains(this);
  String get label => switch (this) {
        FileKind.word => 'Word',
        FileKind.sheet => 'Spreadsheet',
        FileKind.slides => 'Presentation',
        FileKind.pdf => 'PDF',
        FileKind.text => 'Text',
        FileKind.markdown => 'Markdown',
        FileKind.csv => 'CSV',
        FileKind.code => 'Code',
        FileKind.image => 'Image',
        FileKind.archive => 'Archive',
        FileKind.ebook => 'E-book',
        FileKind.font => 'Font',
        FileKind.binary => 'File',
      };
  IconData get icon => switch (this) {
        FileKind.word => Icons.article_outlined,
        FileKind.sheet => Icons.table_chart_outlined,
        FileKind.slides => Icons.slideshow_outlined,
        FileKind.pdf => Icons.picture_as_pdf_outlined,
        FileKind.text => Icons.notes_outlined,
        FileKind.markdown => Icons.code_off_outlined,
        FileKind.csv => Icons.grid_on_outlined,
        FileKind.code => Icons.code_outlined,
        FileKind.image => Icons.image_outlined,
        FileKind.archive => Icons.folder_zip_outlined,
        FileKind.ebook => Icons.menu_book_outlined,
        FileKind.font => Icons.font_download_outlined,
        FileKind.binary => Icons.insert_drive_file_outlined,
      };
  Color accent(ColorScheme scheme) => switch (this) {
        FileKind.word => const Color(0xFF5B84B1),
        FileKind.sheet => const Color(0xFF5E9E7E),
        FileKind.slides => const Color(0xFFD08A4E),
        FileKind.pdf => const Color(0xFFBE6A5F),
        FileKind.text => const Color(0xFF8A8078),
        FileKind.markdown => const Color(0xFF7A8FA3),
        FileKind.csv => const Color(0xFF6FA0A0),
        FileKind.code => const Color(0xFF9B7FB0),
        FileKind.image => const Color(0xFF8FA05B),
        FileKind.archive => const Color(0xFFA99060),
        FileKind.ebook => const Color(0xFF9C7C9E),
        FileKind.font => const Color(0xFF8A8F96),
        FileKind.binary => const Color(0xFF9A9188),
      };
}
const Map<String, FileKind> _byExtension = {
  'docx': FileKind.word,
  'docm': FileKind.word,
  'dotx': FileKind.word,
  'dotm': FileKind.word,
  'odt': FileKind.word,
  'rtf': FileKind.word,
  'doc': FileKind.word,
  'xlsx': FileKind.sheet,
  'xlsm': FileKind.sheet,
  'xltx': FileKind.sheet,
  'xlsb': FileKind.sheet,
  'xls': FileKind.sheet,
  'ods': FileKind.sheet,
  'numbers': FileKind.sheet,
  'pptx': FileKind.slides,
  'pptm': FileKind.slides,
  'potx': FileKind.slides,
  'ppt': FileKind.slides,
  'odp': FileKind.slides,
  'key': FileKind.slides,
  'pdf': FileKind.pdf,
  'md': FileKind.markdown,
  'markdown': FileKind.markdown,
  'mdx': FileKind.markdown,
  'txt': FileKind.text,
  'log': FileKind.text,
  'text': FileKind.text,
  'nfo': FileKind.text,
  'csv': FileKind.csv,
  'tsv': FileKind.csv,
  'json': FileKind.code,
  'dart': FileKind.code,
  'js': FileKind.code,
  'jsx': FileKind.code,
  'ts': FileKind.code,
  'tsx': FileKind.code,
  'py': FileKind.code,
  'rb': FileKind.code,
  'go': FileKind.code,
  'rs': FileKind.code,
  'java': FileKind.code,
  'kt': FileKind.code,
  'kts': FileKind.code,
  'c': FileKind.code,
  'h': FileKind.code,
  'cpp': FileKind.code,
  'hpp': FileKind.code,
  'cc': FileKind.code,
  'cs': FileKind.code,
  'swift': FileKind.code,
  'php': FileKind.code,
  'sh': FileKind.code,
  'bash': FileKind.code,
  'zsh': FileKind.code,
  'ps1': FileKind.code,
  'bat': FileKind.code,
  'cmd': FileKind.code,
  'sql': FileKind.code,
  'html': FileKind.code,
  'htm': FileKind.code,
  'css': FileKind.code,
  'scss': FileKind.code,
  'less': FileKind.code,
  'xml': FileKind.code,
  'yaml': FileKind.code,
  'yml': FileKind.code,
  'toml': FileKind.code,
  'ini': FileKind.code,
  'gradle': FileKind.code,
  'cmake': FileKind.code,
  'lua': FileKind.code,
  'pl': FileKind.code,
  'r': FileKind.code,
  'm': FileKind.code,
  'vue': FileKind.code,
  'svelte': FileKind.code,
  't': FileKind.code,
  'mts': FileKind.code,
  'png': FileKind.image,
  'jpg': FileKind.image,
  'jpeg': FileKind.image,
  'gif': FileKind.image,
  'webp': FileKind.image,
  'bmp': FileKind.image,
  'heic': FileKind.image,
  'heif': FileKind.image,
  'ico': FileKind.image,
  'tif': FileKind.image,
  'tiff': FileKind.image,
  'svg': FileKind.image,
  'avif': FileKind.image,
  'zip': FileKind.archive,
  'rar': FileKind.archive,
  '7z': FileKind.archive,
  'tar': FileKind.archive,
  'gz': FileKind.archive,
  'bz2': FileKind.archive,
  'xz': FileKind.archive,
  'zst': FileKind.archive,
  'apk': FileKind.archive,
  'iso': FileKind.archive,
  'jar': FileKind.archive,
  'obb': FileKind.archive,
  'epub': FileKind.ebook,
  'mobi': FileKind.ebook,
  'azw': FileKind.ebook,
  'azw3': FileKind.ebook,
  'fb2': FileKind.ebook,
  'ttf': FileKind.font,
  'otf': FileKind.font,
  'woff': FileKind.font,
  'woff2': FileKind.font,
};
FileKind kindForName(String name) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return FileKind.binary;
  final ext = name.substring(dot + 1).toLowerCase();
  return _byExtension[ext] ?? FileKind.binary;
}
bool isEditableName(String name) => kindForName(name).isEditable;
bool isSupportedName(String name) => kindForName(name) != FileKind.binary;
String? mimeForName(String name) {
  switch (kindForName(name)) {
    case FileKind.word:
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case FileKind.sheet:
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case FileKind.slides:
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    case FileKind.pdf:
      return 'application/pdf';
    case FileKind.markdown:
    case FileKind.text:
      return 'text/plain';
    case FileKind.csv:
      return 'text/csv';
    case FileKind.image:
      return 'image/*';
    default:
      return null;
  }
}
String lookupMime(String path) {
  final dot = path.lastIndexOf('.');
  final ext = dot <= 0 ? '' : path.substring(dot + 1).toLowerCase();
  return switch (ext) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'bmp' => 'image/bmp',
    'svg' => 'image/svg+xml',
    'pdf' => 'application/pdf',
    'mp3' => 'audio/mpeg',
    'm4a' => 'audio/mp4',
    'wav' => 'audio/wav',
    'flac' => 'audio/flac',
    'ogg' => 'audio/ogg',
    'mp4' => 'video/mp4',
    'webm' => 'video/webm',
    'mkv' => 'video/x-matroska',
    'mov' => 'video/quicktime',
    'txt' => 'text/plain',
    'csv' => 'text/csv',
    'html' => 'text/html',
    'json' => 'application/json',
    'zip' => 'application/zip',
    _ => 'application/octet-stream',
  };
}
