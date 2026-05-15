import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hapt_photo_picker/hapt_photo_picker.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HaptPhotoPicker Demo',
      theme: ThemeData(useMaterial3: true),
      home: const _Home(),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  List<HaptPickerResult> _picked = const [];

  Future<void> _openDefault() async {
    final r = await HaptPhotoPicker.pick(
      context,
      config: const HaptPickerConfig(
        maxSelection: 4,
        aspectRatios: [
          HaptAspectRatio.original,
          HaptAspectRatio.square,
          HaptAspectRatio.portrait,
        ],
      ),
    );
    if (r != null) setState(() => _picked = r);
  }

  /// Demonstrates the full customization surface — colors,
  /// typography, custom strings (Vietnamese), pipeline transform.
  Future<void> _openBranded() async {
    final winePalette = HaptPickerTheme.light().copyWith(
      colors: HaptPickerTheme.light().colors.copyWith(
            primary: const Color(0xFF850E35),
            selectionBadge: const Color(0xFFEE6983),
            selectionOverlay: const Color(0x33EE6983),
          ),
      typography: HaptPickerTypography.fromFamily('Inter'),
      radii: const HaptPickerRadii(thumbnail: 6),
    );
    final r = await HaptPhotoPicker.pick(
      context,
      config: const HaptPickerConfig(maxSelection: 3),
      theme: winePalette,
      strings: const HaptPickerStringsVi(),
      pipeline: const [_LogTransform()],
    );
    if (r != null) setState(() => _picked = r);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HaptPhotoPicker')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: _openDefault,
              child: const Text('Open with defaults'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _openBranded,
              child: const Text('Open with branded theme + Vietnamese'),
            ),
            const SizedBox(height: 24),
            Text('Picked ${_picked.length} item(s):',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: _picked.length,
                itemBuilder: (_, i) => FutureBuilder<Uint8List?>(
                  future: _picked[i].processedBytes != null
                      ? Future.value(_picked[i].processedBytes)
                      : _picked[i].asset.readThumbnail(),
                  builder: (_, snap) {
                    final b = snap.data;
                    if (b == null) {
                      return Container(color: Colors.grey.shade300);
                    }
                    return Image.memory(b, fit: BoxFit.cover);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trivial pipeline transform — passthrough + log to console. Real
/// apps would do auto-exposure, watermark, etc. here.
class _LogTransform extends HaptAssetTransform {
  const _LogTransform();
  @override
  String get id => 'example.log';
  @override
  Future<HaptTransformResult> run({
    required HaptAsset asset,
    required Uint8List? incomingBytes,
    required HaptTransformContext context,
  }) async {
    // ignore: avoid_print
    print('[HaptPhotoPicker] transform fired for ${asset.id} '
        '(${context.indexInSelection + 1}/${context.totalSelected})');
    return HaptTransformResult.passthrough(asset);
  }
}
