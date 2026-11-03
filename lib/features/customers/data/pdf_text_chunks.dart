import 'package:characters/characters.dart';

/// Bounds table-row height while retaining every character in source order.
/// Prefer whitespace boundaries so ordinary Arabic/English words stay intact.
/// A token longer than a row budget must wrap: split it only between grapheme
/// clusters, never inside a surrogate pair, diacritic sequence or ZWJ sequence.
List<String> pdfTextChunks(
  String text, {
  int maxGraphemes = 240,
  int maxLineBreaks = 8,
}) {
  if (maxGraphemes < 1) throw ArgumentError.value(maxGraphemes);
  if (maxLineBreaks < 1) throw ArgumentError.value(maxLineBreaks);
  final graphemes = text.characters.toList();
  final chunks = <String>[];
  var start = 0;
  while (start < graphemes.length) {
    var end = (start + maxGraphemes).clamp(0, graphemes.length);
    var breaks = 0;
    for (var i = start; i < end; i++) {
      if (graphemes[i].contains('\n') || graphemes[i].contains('\r')) {
        breaks++;
        if (breaks == maxLineBreaks) {
          end = i + 1;
          break;
        }
      }
    }
    if (end < graphemes.length) {
      for (var boundary = end; boundary > start; boundary--) {
        if (graphemes[boundary - 1].trim().isEmpty) {
          end = boundary;
          break;
        }
      }
    }
    chunks.add(graphemes.sublist(start, end).join());
    start = end;
  }
  return chunks;
}
