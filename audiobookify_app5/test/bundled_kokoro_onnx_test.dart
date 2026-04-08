import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kokoro_flutter/kokoro_flutter.dart';

import 'package:audiobookify/services/bundled_kokoro_onnx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'buildBundledKokoroOnnxFactory returns a factory when assets are present',
    () async {
      final factory = await buildBundledKokoroOnnxFactory(
        bundle: _FakeAssetBundle.withKokoroAssets(),
      );

      expect(factory, isNotNull);
    },
  );

  test(
    'buildBundledKokoroOnnxFactory returns null when assets are missing',
    () async {
      final factory = await buildBundledKokoroOnnxFactory(
        bundle: _FakeAssetBundle.withKokoroAssets(includeModel: false),
      );

      expect(factory, isNull);
    },
  );

  test('bundled Kokoro config uses Apple providers by default', () {
    final config = buildBundledKokoroOnnxConfig(operatingSystem: 'ios');

    expect(config.providers, const <OrtProvider>[
      OrtProvider.CORE_ML,
      OrtProvider.CPU,
    ]);
  });

  test('bundled Kokoro config uses Android providers by default', () {
    final config = buildBundledKokoroOnnxConfig(operatingSystem: 'android');

    expect(config.providers, const <OrtProvider>[
      OrtProvider.QNN,
      OrtProvider.NNAPI,
      OrtProvider.XNNPACK,
      OrtProvider.CPU,
    ]);
  });

  test('bundled Kokoro config uses Windows providers by default', () {
    final config = buildBundledKokoroOnnxConfig(operatingSystem: 'windows');

    expect(config.providers, const <OrtProvider>[
      OrtProvider.DIRECT_ML,
      OrtProvider.CPU,
    ]);
  });

  test('bundled Kokoro config uses CPU only on Linux', () {
    final config = buildBundledKokoroOnnxConfig(operatingSystem: 'linux');

    expect(config.providers, const <OrtProvider>[OrtProvider.CPU]);
  });
}

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this._assets);

  factory _FakeAssetBundle.withKokoroAssets({bool includeModel = true}) {
    final manifest = <String, dynamic>{
      if (includeModel)
        kokoroModelAssetPath: <dynamic>[
          <String, dynamic>{'asset': kokoroModelAssetPath},
        ],
      kokoroVoicesAssetPath: <dynamic>[
        <String, dynamic>{'asset': kokoroVoicesAssetPath},
      ],
      kokoroVocabAssetPath: <dynamic>[
        <String, dynamic>{'asset': kokoroVocabAssetPath},
      ],
      kokoroLexiconAssetPath: <dynamic>[
        <String, dynamic>{'asset': kokoroLexiconAssetPath},
      ],
    };

    return _FakeAssetBundle(<String, ByteData>{
      'AssetManifest.bin': const StandardMessageCodec().encodeMessage(
        manifest,
      )!,
      kokoroVoicesAssetPath: _utf8Data('{"af_heart":[[0.1,0.2,0.3]]}'),
      kokoroVocabAssetPath: _utf8Data('{"a":1}'),
      kokoroLexiconAssetPath: _utf8Data('{"hello":"h ə l oʊ"}'),
      if (includeModel) kokoroModelAssetPath: ByteData(4),
    });
  }

  final Map<String, ByteData> _assets;

  @override
  Future<ByteData> load(String key) async {
    final data = _assets[key];
    if (data == null) {
      throw StateError('Missing asset: $key');
    }
    return data;
  }

  static ByteData _utf8Data(String value) {
    final bytes = Uint8List.fromList(utf8.encode(value));
    return ByteData.sublistView(bytes);
  }
}
