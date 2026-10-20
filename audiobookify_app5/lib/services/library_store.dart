import 'dart:io';

import '../objectbox.g.dart';

/// ObjectBox's POSIX semaphore prefix must match a macOS app-group entitlement.
/// This does not move the database into a shared container.
const libraryMacosApplicationGroup = '3YWW337ZMW.abook';

Future<Store> openLibraryStore({required String directory}) => openStore(
  directory: directory,
  macosApplicationGroup: Platform.isMacOS ? libraryMacosApplicationGroup : null,
);
