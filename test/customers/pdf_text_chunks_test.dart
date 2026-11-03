import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:target/features/customers/data/pdf_text_chunks.dart';

void main() {
  test('Arabic diacritics and supplementary/ZWJ characters stay intact', () {
    final text = '${List.filled(239, 'س').join()}بَ👨‍👩‍👧‍👦😀قية';
    final chunks = pdfTextChunks(text);
    expect(chunks.join(), text);
    expect(chunks.first.endsWith('بَ'), isTrue);
    expect(chunks.expand((s) => s.characters), text.characters);
    expect(chunks.every((s) => s.characters.length <= 240), isTrue);
  });
  for (final word in ['عَرَبِيَّة', 'English']) {
    test('long $word paragraphs preserve ordinary words and all whitespace', () {
      final text = List.filled(1000, '$word \n').join();
      final chunks = pdfTextChunks(text);
      expect(chunks.join(), text);
      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks.take(chunks.length - 1)) {
        expect(chunk.endsWith(' ') || chunk.endsWith('\n'), isTrue);
      }
    });
  }
  test('overlong unbroken tokens wrap only at grapheme boundaries', () {
    final text = List.filled(1000, 'بَ').join();
    final chunks = pdfTextChunks(text);
    expect(chunks.join(), text);
    expect(chunks.every((c) => c.startsWith('ب') && c.endsWith('َ')), isTrue);
  });
  test('empty input and invalid budgets are explicit', () {
    expect(pdfTextChunks(''), isEmpty);
    expect(() => pdfTextChunks('text', maxGraphemes: 0), throwsArgumentError);
  });
}
