import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/services/slugify.dart';

void main() {
  test('lowercases and trims', () {
    expect(slugify('  Kilimo Mkononi  '), 'kilimo-mkononi');
  });

  test('collapses internal whitespace to a single hyphen', () {
    expect(slugify('Coffee   Core'), 'coffee-core');
  });

  test('strips punctuation', () {
    expect(slugify('AlmaWorks!'), 'almaworks');
    expect(slugify("Nyumba's Smart Home"), 'nyumbas-smart-home');
  });

  test('preserves existing hyphens and digits', () {
    expect(slugify('Alma-Hub 2.0'), 'alma-hub-20');
  });

  test('falls back to "entity" for a name with no alphanumeric characters', () {
    expect(slugify('!!!'), 'entity');
    expect(slugify(''), 'entity');
    expect(slugify('   '), 'entity');
  });
}
