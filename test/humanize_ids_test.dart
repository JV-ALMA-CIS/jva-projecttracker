import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/utils/humanize_ids.dart';

void main() {
  const id = 'aB3xK9pQ2mZ7rT1vW8yL';
  const names = {id: 'KILIMO MKONONI digital extension tender'};

  test('replaces a bracketed ID with the opportunity title', () {
    expect(
      humanizeIds('Fast-track [$id] before the deadline.', names),
      'Fast-track "KILIMO MKONONI digital extension tender" before the '
      'deadline.',
    );
  });

  test('replaces parenthesised and bare IDs', () {
    expect(
      humanizeIds('The tender ($id) is strong.', names),
      'The tender "KILIMO MKONONI digital extension tender" is strong.',
    );
    expect(
      humanizeIds('Opportunity $id is strong.', names),
      'Opportunity "KILIMO MKONONI digital extension tender" is strong.',
    );
  });

  test('removes unknown IDs without leaving empty brackets', () {
    expect(
      humanizeIds('Pursue the tender (Zq8Lm2Nx4Pv6Rt9Sw1Ky) now.', names),
      'Pursue the tender now.',
    );
  });

  test('leaves ordinary words, codes and single-case long words alone', () {
    const text =
        'KILIMOMKONONI tender ref KE-2026-0042 (EU funded): '
        'internationalisation matters';
    expect(humanizeIds(text, names), text);
  });
}
