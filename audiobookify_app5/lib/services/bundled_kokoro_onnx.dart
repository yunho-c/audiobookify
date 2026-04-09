import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kokoro_flutter/kokoro_flutter.dart';

import 'open_tts_backend.dart';

const String kokoroModelAssetPath = 'assets/kokoro/kokoro-v1.0.onnx';
const String kokoroVoicesAssetPath = 'assets/kokoro/voices.json';
const String kokoroVocabAssetPath = 'assets/kokoro/tokenizer_vocab.json';
const String kokoroLexiconAssetPath = 'assets/kokoro/lexicon.json';

const List<String> _requiredKokoroAssetPaths = <String>[
  kokoroModelAssetPath,
  kokoroVoicesAssetPath,
  kokoroVocabAssetPath,
  kokoroLexiconAssetPath,
];

enum OpenTtsExecutionProviderOverride {
  auto,
  coreMl,
  qnn,
  nnapi,
  xnnpack,
  directMl,
  cpu,
}

List<OpenTtsExecutionProviderOverride>
bundledKokoroProviderOverridesForPlatform(String operatingSystem) {
  switch (operatingSystem) {
    case 'ios':
    case 'macos':
      return const <OpenTtsExecutionProviderOverride>[
        OpenTtsExecutionProviderOverride.auto,
        OpenTtsExecutionProviderOverride.coreMl,
        OpenTtsExecutionProviderOverride.cpu,
      ];
    case 'android':
      return const <OpenTtsExecutionProviderOverride>[
        OpenTtsExecutionProviderOverride.auto,
        OpenTtsExecutionProviderOverride.qnn,
        OpenTtsExecutionProviderOverride.nnapi,
        OpenTtsExecutionProviderOverride.xnnpack,
        OpenTtsExecutionProviderOverride.cpu,
      ];
    case 'windows':
      return const <OpenTtsExecutionProviderOverride>[
        OpenTtsExecutionProviderOverride.auto,
        OpenTtsExecutionProviderOverride.directMl,
        OpenTtsExecutionProviderOverride.cpu,
      ];
    case 'linux':
    default:
      return const <OpenTtsExecutionProviderOverride>[
        OpenTtsExecutionProviderOverride.auto,
      ];
  }
}

String bundledKokoroProviderOverrideLabel(
  OpenTtsExecutionProviderOverride override,
  String operatingSystem,
) {
  switch (override) {
    case OpenTtsExecutionProviderOverride.auto:
      return 'Auto';
    case OpenTtsExecutionProviderOverride.coreMl:
      return 'CoreML + CPU fallback';
    case OpenTtsExecutionProviderOverride.qnn:
      return 'QNN + CPU fallback';
    case OpenTtsExecutionProviderOverride.nnapi:
      return 'NNAPI + CPU fallback';
    case OpenTtsExecutionProviderOverride.xnnpack:
      return 'XNNPACK + CPU fallback';
    case OpenTtsExecutionProviderOverride.directMl:
      return 'DirectML + CPU fallback';
    case OpenTtsExecutionProviderOverride.cpu:
      return operatingSystem == 'linux' ? 'CPU' : 'CPU only';
  }
}

OpenTtsExecutionProviderOverride loadOpenTtsExecutionProviderOverrideFromName(
  String? value,
) {
  return OpenTtsExecutionProviderOverride.values.firstWhere(
    (candidate) => candidate.name == value,
    orElse: () => OpenTtsExecutionProviderOverride.auto,
  );
}

@visibleForTesting
List<OrtProvider> bundledKokoroProvidersForPlatform(
  String operatingSystem, {
  OpenTtsExecutionProviderOverride providerOverride =
      OpenTtsExecutionProviderOverride.auto,
}) {
  if (providerOverride != OpenTtsExecutionProviderOverride.auto) {
    if (providerOverride == OpenTtsExecutionProviderOverride.cpu) {
      return const <OrtProvider>[OrtProvider.CPU];
    }
    if (providerOverride == OpenTtsExecutionProviderOverride.coreMl &&
        (operatingSystem == 'ios' || operatingSystem == 'macos')) {
      return const <OrtProvider>[OrtProvider.CORE_ML, OrtProvider.CPU];
    }
    if (providerOverride == OpenTtsExecutionProviderOverride.qnn &&
        operatingSystem == 'android') {
      return const <OrtProvider>[OrtProvider.QNN, OrtProvider.CPU];
    }
    if (providerOverride == OpenTtsExecutionProviderOverride.nnapi &&
        operatingSystem == 'android') {
      return const <OrtProvider>[OrtProvider.NNAPI, OrtProvider.CPU];
    }
    if (providerOverride == OpenTtsExecutionProviderOverride.xnnpack &&
        operatingSystem == 'android') {
      return const <OrtProvider>[OrtProvider.XNNPACK, OrtProvider.CPU];
    }
    if (providerOverride == OpenTtsExecutionProviderOverride.directMl &&
        operatingSystem == 'windows') {
      return const <OrtProvider>[OrtProvider.DIRECT_ML, OrtProvider.CPU];
    }
  }

  switch (operatingSystem) {
    case 'ios':
    case 'macos':
      return const <OrtProvider>[OrtProvider.CORE_ML, OrtProvider.CPU];
    case 'android':
      return const <OrtProvider>[
        OrtProvider.QNN,
        OrtProvider.NNAPI,
        OrtProvider.XNNPACK,
        OrtProvider.CPU,
      ];
    case 'windows':
      return const <OrtProvider>[OrtProvider.DIRECT_ML, OrtProvider.CPU];
    case 'linux':
    default:
      return const <OrtProvider>[OrtProvider.CPU];
  }
}

@visibleForTesting
KokoroOnnxConfig buildBundledKokoroOnnxConfig({
  String? operatingSystem,
  OpenTtsExecutionProviderOverride providerOverride =
      OpenTtsExecutionProviderOverride.auto,
}) {
  final String os = operatingSystem ?? Platform.operatingSystem;
  return KokoroOnnxConfig(
    modelPath: kokoroModelAssetPath,
    voicesPath: kokoroVoicesAssetPath,
    vocabPath: kokoroVocabAssetPath,
    lexiconPath: kokoroLexiconAssetPath,
    baseDir: _desktopFlutterAssetsBaseDir(),
    providers: bundledKokoroProvidersForPlatform(
      os,
      providerOverride: providerOverride,
    ),
  );
}

Future<OpenTtsFactory?> buildBundledKokoroOnnxFactory({
  AssetBundle? bundle,
  OpenTtsExecutionProviderOverride Function()? providerOverrideResolver,
  String? operatingSystem,
}) async {
  final assetBundle = bundle ?? rootBundle;
  if (kIsWeb) {
    return null;
  }
  final bool isReady = await bundledKokoroAssetsReady(bundle: assetBundle);
  if (!isReady) {
    return null;
  }

  return (renderer) async => OpenTts(
    engine: KokoroOnnx(
      config: buildBundledKokoroOnnxConfig(
        operatingSystem: operatingSystem,
        providerOverride:
            providerOverrideResolver?.call() ??
            OpenTtsExecutionProviderOverride.auto,
      ),
    ),
    renderer: renderer,
    useStreamingForSpeak: false,
  );
}

Future<bool> bundledKokoroAssetsReady({AssetBundle? bundle}) async {
  final assetBundle = bundle ?? rootBundle;
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(assetBundle);
    final assetKeys = manifest.listAssets().toSet();
    if (_requiredKokoroAssetPaths.any((path) => !assetKeys.contains(path))) {
      return false;
    }

    final voices = json.decode(
      await assetBundle.loadString(kokoroVoicesAssetPath),
    );
    if (voices is! Map || voices.isEmpty) {
      return false;
    }

    final vocab = json.decode(
      await assetBundle.loadString(kokoroVocabAssetPath),
    );
    if (vocab is! Map && vocab is! List) {
      return false;
    }

    final lexicon = json.decode(
      await assetBundle.loadString(kokoroLexiconAssetPath),
    );
    if (lexicon is! Map && lexicon is! List) {
      return false;
    }

    return true;
  } catch (_) {
    return false;
  }
}

String? _desktopFlutterAssetsBaseDir() {
  if (!(Platform.isLinux || Platform.isWindows)) {
    return null;
  }

  final separator = Platform.pathSeparator;
  final executableDir = File(Platform.resolvedExecutable).parent.path;
  final builtAppAssets =
      '$executableDir${separator}data${separator}flutter_assets';
  if (Directory(builtAppAssets).existsSync()) {
    return builtAppAssets;
  }

  return Directory.current.path;
}
