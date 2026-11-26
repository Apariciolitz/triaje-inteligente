import 'package:flutter/widgets.dart';
import 'app_state.dart';

/// Da acceso al estado a cualquier pantalla: `Estado.de(context)`.
class Estado extends InheritedNotifier<AppState> {
  const Estado({super.key, required AppState estado, required super.child}) : super(notifier: estado);
  static AppState de(BuildContext context) => context.dependOnInheritedWidgetOfExactType<Estado>()!.notifier!;
}
