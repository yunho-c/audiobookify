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

@visibleForTesting
List<OrtProvider> bundledKokoroProvidersForPlatform(String operatingSystem) {
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
KokoroOnnxConfig buildBundledKokoroOnnxConfig({String? operatingSystem}) {
  final String os = operatingSystem ?? Platform.operatingSystem;
  return KokoroOnnxConfig(
    modelPath: kokoroModelAssetPath,
    voicesPath: kokoroVoicesAssetPath,
    vocabPath: kokoroVocabAssetPath,
    lexiconPath: kokoroLexiconAssetPath,
    baseDir: _desktopFlutterAssetsBaseDir(),
    providers: bundledKokoroProvidersForPlatform(os),
  );
}

Future<OpenTtsFactory?> buildBundledKokoroOnnxFactory({
  AssetBundle? bundle,
}) async {
  final assetBundle = bundle ?? rootBundle;
  if (kIsWeb) {
    return null;
  }
  final bool isReady = await bundledKokoroAssetsReady(bundle: assetBundle);
  if (!isReady) {
    return null;
  }

  final config = buildBundledKokoroOnnxConfig();

  return (renderer) async => OpenTts(
    engine: KokoroOnnx(config: config),
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
