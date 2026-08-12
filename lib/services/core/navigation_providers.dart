import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which `HomeShell` tab is selected — lifted out of `HomeShell`'s local
/// state so global chrome (the command palette's "Go to" entries) can
/// switch tabs the same way tapping the nav bar/rail does, instead of
/// pushing a duplicate screen onto the Navigator. Same shape as
/// [ThemeModeController]/[AppLocaleController].
class SelectedTabIndexController extends Notifier<int> {
  @override
  int build() => 0;

  set index(int value) => state = value;
}

final selectedTabIndexProvider =
    NotifierProvider<SelectedTabIndexController, int>(
      SelectedTabIndexController.new,
    );
