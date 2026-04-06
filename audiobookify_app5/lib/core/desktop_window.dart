import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

enum DesktopWindowPlatform { none, macos, windows }

const Size kDesktopWindowInitialSize = Size(1280, 720);
const Size kDesktopWindowMinimumSize = Size(960, 640);
const double kDesktopMacTitleBarHeight = 32;
const double kDesktopMacContentTopInset = 25;

DesktopWindowPlatform get desktopWindowPlatform {
  if (kIsWeb) return DesktopWindowPlatform.none;
  if (Platform.isMacOS) return DesktopWindowPlatform.macos;
  if (Platform.isWindows) return DesktopWindowPlatform.windows;
  return DesktopWindowPlatform.none;
}

bool get isDesktopWindowChromeEnabled =>
    desktopWindowPlatform != DesktopWindowPlatform.none;

bool get isDesktopWindowMacOS =>
    desktopWindowPlatform == DesktopWindowPlatform.macos;

bool get isDesktopWindowWindows =>
    desktopWindowPlatform == DesktopWindowPlatform.windows;

Future<void> configureDesktopWindow() async {
  if (!isDesktopWindowChromeEnabled) return;

  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: kDesktopWindowInitialSize,
    minimumSize: kDesktopWindowMinimumSize,
    center: true,
    title: 'Audiobookify',
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: true,
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
