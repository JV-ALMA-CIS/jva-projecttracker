import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/services/notification_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late NotificationPreferencesService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    service = NotificationPreferencesService(prefs);
  });

  test('readIds is empty by default', () {
    expect(service.readIds, isEmpty);
  });

  test('markRead adds the id to readIds', () async {
    await service.markRead('recommendation:rec-1');

    expect(service.readIds, {'recommendation:rec-1'});
  });

  test('markRead accumulates across multiple calls', () async {
    await service.markRead('recommendation:rec-1');
    await service.markRead('deadline:opp-1');

    expect(service.readIds, {'recommendation:rec-1', 'deadline:opp-1'});
  });

  test('markAllRead adds every id at once', () async {
    await service.markAllRead(['recommendation:rec-1', 'deadline:opp-1']);

    expect(service.readIds, {'recommendation:rec-1', 'deadline:opp-1'});
  });

  test(
    'read state persists across a new service instance over the same prefs',
    () async {
      await service.markRead('recommendation:rec-1');

      final prefs = await SharedPreferences.getInstance();
      final reloaded = NotificationPreferencesService(prefs);

      expect(reloaded.readIds, {'recommendation:rec-1'});
    },
  );
}
