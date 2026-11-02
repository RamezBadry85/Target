import 'dart:ui';

import 'package:flutter/material.dart';

import 'app/target_app.dart';
import 'core/logging/app_logger.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.error('Flutter framework failure', details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('Unhandled asynchronous failure', error, stack);
    return true;
  };
  runApp(const TargetApp());
}
