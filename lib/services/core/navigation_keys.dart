import 'package:flutter/widgets.dart';

/// The app's single [Navigator], reachable from places that have no
/// [BuildContext] of their own — chiefly `PushNotificationService`, which
/// reacts to a notification tap from outside the widget tree (the app may
/// not even be running yet when the tap happens) and needs a way to push a
/// route once it comes up. Assigned to `MaterialApp.navigatorKey` in
/// `main.dart`.
final rootNavigatorKey = GlobalKey<NavigatorState>();
