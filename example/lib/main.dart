import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kindling/kindling.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(home: Scaffold(body: const DemoApp())));
}

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  late final SkeletalPreviewGame _game;
  final TextEditingController _importController = TextEditingController();
  final TextEditingController _assetBasePathController =
      TextEditingController();

  double _blendDurationMs = 350;
  String _selectedClip = 'idle';
  bool _autoSwitch = false;

  @override
  void initState() {
    super.initState();
    _game = SkeletalPreviewGame(
      initialClip: _selectedClip,
      initialBlendDurationMs: _blendDurationMs,
      initialAutoSwitch: _autoSwitch,
    );
  }

  void _playClip(String clipName) {
    setState(() {
      _selectedClip = clipName;
      _autoSwitch = false;
    });

    _game.setAutoSwitch(false);
    _game.playClip(clipName, restart: true);
  }

  Future<void> _openImportDialog() async {
    _importController.text = await Clipboard.getData(
      'text/plain',
    ).then((value) => value?.text ?? '').catchError((_) => '');
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Importar SkeletonProject JSON'),
          content: SizedBox(
            width: 760,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: _assetBasePathController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Pasta base das imagens PNG',
                    hintText: '/caminho/para/a/pasta/do/json',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _importController,
                  maxLines: 24,
                  minLines: 16,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Cole aqui o JSON exportado pelo kindling_editor',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                try {
                  final decoded = jsonDecode(_importController.text);
                  if (decoded is! Map<String, dynamic>) {
                    throw const FormatException('JSON invalido.');
                  }

                  final project = SkeletonProject.fromJson(decoded);
                  await _game.loadProject(
                    project,
                    assetBasePath: _assetBasePathController.text.trim(),
                  );

                  final firstClip = project.animationClips.isNotEmpty
                      ? project.animationClips.first.name
                      : 'idle';

                  if (!mounted) {
                    return;
                  }

                  setState(() {
                    _selectedClip = firstClip;
                    _autoSwitch = false;
                  });

                  _game.setAutoSwitch(false);
                  if (project.animationClips.isNotEmpty) {
                    _game.playClip(firstClip, restart: true);
                  }

                  navigator.pop();
                  if (!mounted) {
                    return;
                  }
                  final messenger = ScaffoldMessenger.of(this.context);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Projeto importado no preview.'),
                    ),
                  );
                } on FormatException catch (error) {
                  if (!mounted) {
                    return;
                  }
                  final messenger = ScaffoldMessenger.of(this.context);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Falha ao importar JSON: ${error.message}'),
                    ),
                  );
                } catch (error) {
                  if (!mounted) {
                    return;
                  }
                  final messenger = ScaffoldMessenger.of(this.context);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Falha ao importar projeto: $error'),
                    ),
                  );
                }
              },
              child: const Text('Importar'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _importController.dispose();
    _assetBasePathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF101418),
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              GameWidget(game: _game),
              Positioned(
                left: 12,
                top: 12,
                child: _HudCard(
                  selectedClip: _selectedClip,
                  blendDurationMs: _blendDurationMs,
                  autoSwitch: _autoSwitch,
                  onPlayIdle: () => _playClip('idle'),
                  onPlayWave: () => _playClip('wave'),
                  onBlendChanged: (value) {
                    setState(() {
                      _blendDurationMs = value;
                    });
                    _game.setBlendDurationMs(value);
                  },
                  onAutoSwitchChanged: (enabled) {
                    setState(() {
                      _autoSwitch = enabled;
                    });
                    _game.setAutoSwitch(enabled);
                  },
                  onImportJson: _openImportDialog,
                  assetBasePathController: _assetBasePathController,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SkeletalPreviewGame extends FlameGame {
  SkeletalPreviewGame({
    required String initialClip,
    required double initialBlendDurationMs,
    required bool initialAutoSwitch,
  }) : _currentClipName = initialClip,
       _blendDurationMs = initialBlendDurationMs,
       _autoSwitch = initialAutoSwitch;

  SkeletalAnimationComponent? _skeletal;
  late SkeletonProject _project;

  String _currentClipName;
  double _blendDurationMs;
  bool _autoSwitch;

  double _switchTimerSeconds = 0.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _project = _buildDemoProject();
    await _loadProjectIntoScene(_project, assetBasePath: '');
  }

  Future<void> loadProject(
    SkeletonProject project, {
    required String assetBasePath,
  }) async {
    _project = project;
    _currentClipName = project.animationClips.isNotEmpty
        ? project.animationClips.first.name
        : _currentClipName;
    _switchTimerSeconds = 0.0;
    await _loadProjectIntoScene(project, assetBasePath: assetBasePath);
  }

  Future<void> _loadProjectIntoScene(
    SkeletonProject project, {
    required String assetBasePath,
  }) async {
    final sprites = <String, Sprite>{};
    final sizes = <String, Vector2>{};

    for (var index = 0; index < project.bones.length; index++) {
      final bone = project.bones[index];
      final spriteImage = await _tryLoadSpriteImage(
        basePath: assetBasePath,
        spritePath: bone.spritePath,
      );
      if (spriteImage != null) {
        sprites[bone.id] = Sprite(spriteImage);
        sizes[bone.id] = Vector2(
          spriteImage.width.toDouble(),
          spriteImage.height.toDouble(),
        );
      } else {
        final color = _colorForIndex(index);
        sprites[bone.id] = await _createBoneSprite(color);
        sizes[bone.id] = Vector2(70 + (index % 3) * 18, 18 + (index % 2) * 8);
      }
    }

    final existing = _skeletal;
    if (existing != null) {
      existing.removeFromParent();
    }

    final skeletal = SkeletalAnimationComponent(
      project: project,
      initialClip: _currentClipName,
      boneSprites: sprites,
      boneSizes: sizes,
    );

    add(skeletal);
    _skeletal = skeletal;
    skeletal.position = size / 2;
    if (project.animationClips.isNotEmpty) {
      skeletal.play(_currentClipName, restart: true);
    }
  }

  Future<ui.Image?> _tryLoadSpriteImage({
    required String basePath,
    required String? spritePath,
  }) async {
    if (spritePath == null || spritePath.isEmpty) {
      return null;
    }

    try {
      final resolvedPath = basePath.isEmpty
          ? spritePath
          : '${basePath.endsWith('/') ? basePath.substring(0, basePath.length - 1) : basePath}/$spritePath';
      final file = File(resolvedPath);
      if (!await file.exists()) {
        return null;
      }
      final bytes = await file.readAsBytes();
      return decodeImageFromList(bytes);
    } catch (_) {
      return null;
    }
  }

  void playClip(String clipName, {bool restart = true}) {
    _currentClipName = clipName;
    _skeletal?.play(
      clipName,
      restart: restart,
      blendDurationMs: _blendDurationMs,
    );
  }

  void setBlendDurationMs(double value) {
    _blendDurationMs = value;
  }

  void setAutoSwitch(bool enabled) {
    _autoSwitch = enabled;
    _switchTimerSeconds = 0.0;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final skeletal = _skeletal;
    if (skeletal == null) {
      return;
    }

    skeletal.position = size / 2;
  }

  @override
  void update(double dt) {
    super.update(dt);

    final skeletal = _skeletal;
    if (skeletal == null) {
      return;
    }

    if (!_autoSwitch) {
      return;
    }

    _switchTimerSeconds += dt;
    if (_switchTimerSeconds < 2.0) {
      return;
    }

    _switchTimerSeconds = 0.0;
    playClip(_currentClipName == 'idle' ? 'wave' : 'idle', restart: true);
  }

  SkeletonProject _buildDemoProject() {
    const bones = <Bone>[
      Bone(
        id: 'root',
        name: 'Root',
        localPosition: Offset.zero,
        localRotation: 0.0,
        localScale: 1.0,
      ),
      Bone(
        id: 'arm',
        name: 'Arm',
        parentId: 'root',
        localPosition: Offset(72, 0),
        localRotation: 0.0,
        localScale: 1.0,
      ),
    ];

    const idle = AnimationClip(
      name: 'idle',
      duration: 1200,
      boneAnimations: <BoneAnimation>[
        BoneAnimation(
          boneId: 'arm',
          rotationKeyframes: <Keyframe>[
            Keyframe(time: 0, value: -0.08),
            Keyframe(time: 600, value: 0.08),
            Keyframe(time: 1200, value: -0.08),
          ],
        ),
      ],
    );

    const wave = AnimationClip(
      name: 'wave',
      duration: 900,
      boneAnimations: <BoneAnimation>[
        BoneAnimation(
          boneId: 'arm',
          rotationKeyframes: <Keyframe>[
            Keyframe(time: 0, value: -0.6),
            Keyframe(time: 225, value: 0.9),
            Keyframe(time: 450, value: -0.6),
            Keyframe(time: 675, value: 0.9),
            Keyframe(time: 900, value: -0.6),
          ],
        ),
      ],
    );

    return const SkeletonProject(
      bones: bones,
      animationClips: <AnimationClip>[idle, wave],
    );
  }

  Future<Sprite> _createBoneSprite(Color color) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    const width = 160.0;
    const height = 32.0;
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, width, height),
      const Radius.circular(10),
    );

    final fillPaint = Paint()..color = color;
    final strokePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(rect, fillPaint);
    canvas.drawRRect(rect, strokePaint);

    final jointPaint = Paint()..color = const Color(0xFFFAFAFA);
    canvas.drawCircle(const Offset(8, height / 2), 5, jointPaint);

    final image = await recorder.endRecording().toImage(160, 32);
    return Sprite(image);
  }

  Color _colorForIndex(int index) {
    const palette = <Color>[
      Color(0xFF2E7D32),
      Color(0xFFEF6C00),
      Color(0xFF1565C0),
      Color(0xFFAD1457),
      Color(0xFF6D4C41),
      Color(0xFF00897B),
    ];
    return palette[index % palette.length];
  }
}

class _HudCard extends StatelessWidget {
  const _HudCard({
    required this.selectedClip,
    required this.blendDurationMs,
    required this.autoSwitch,
    required this.onPlayIdle,
    required this.onPlayWave,
    required this.onBlendChanged,
    required this.onAutoSwitchChanged,
    required this.onImportJson,
    required this.assetBasePathController,
  });

  final String selectedClip;
  final double blendDurationMs;
  final bool autoSwitch;

  final VoidCallback onPlayIdle;
  final VoidCallback onPlayWave;
  final VoidCallback onImportJson;
  final TextEditingController assetBasePathController;
  final ValueChanged<double> onBlendChanged;
  final ValueChanged<bool> onAutoSwitchChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xDD1B2329),
      child: SizedBox(
        width: 280,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Skeletal Runtime HUD',
                style: TextStyle(
                  color: Color(0xFFECEFF1),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Clip atual: $selectedClip',
                style: const TextStyle(color: Color(0xFFCFD8DC)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: assetBasePathController,
                style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'Pasta base imagens',
                  labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                  hintText: '/caminho/para/pasta',
                  hintStyle: TextStyle(color: Color(0xFF64748B)),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onImportJson,
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Importar JSON'),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton(
                      onPressed: onPlayIdle,
                      style: FilledButton.styleFrom(
                        backgroundColor: selectedClip == 'idle'
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFF455A64),
                      ),
                      child: const Text('Play Idle'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: onPlayWave,
                      style: FilledButton.styleFrom(
                        backgroundColor: selectedClip == 'wave'
                            ? const Color(0xFFEF6C00)
                            : const Color(0xFF455A64),
                      ),
                      child: const Text('Play Wave'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Blend: ${blendDurationMs.round()} ms',
                style: const TextStyle(color: Color(0xFFCFD8DC)),
              ),
              Slider(
                min: 0,
                max: 1200,
                divisions: 24,
                value: blendDurationMs,
                onChanged: onBlendChanged,
              ),
              Row(
                children: <Widget>[
                  const Text(
                    'Auto alternar',
                    style: TextStyle(color: Color(0xFFCFD8DC)),
                  ),
                  const Spacer(),
                  Switch(value: autoSwitch, onChanged: onAutoSwitchChanged),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
