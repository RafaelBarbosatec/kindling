import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kindling/kindling.dart';
import 'package:vector_math/vector_math.dart' as vm;

void main() {
  runApp(const KindlingEditorApp());
}

class KindlingEditorApp extends StatelessWidget {
  const KindlingEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        useMaterial3: true,
      ),
      home: const EditorPage(),
    );
  }
}

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage>
    with SingleTickerProviderStateMixin {
  double _timelineDurationMs = 4000;
  static const double _timelineStepMs = 250;
  static const double _pixelsPerSecond = 160;

  late List<Bone> _bones;
  late final Map<String, double> _baseRotations;
  late final Map<String, double> _editedRotations;
  late final Map<String, Map<double, double>> _rotationKeyframes;
  final Map<String, ui.Image> _boneImages = <String, ui.Image>{};

  String? _selectedBoneId;
  double _selectedFrameMs = 0;

  int _nextBoneIndex = 1;

  Offset? _dragPivot;
  double? _dragStartPointerAngle;
  double? _dragStartBoneRotation;

  bool _isPlaying = false;
  double _playbackTimeMs = 0;
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _bones = <Bone>[
      const Bone(
        id: 'root',
        name: 'Root',
        spritePath: null,
        localPosition: Offset(0, 0),
        localRotation: 0,
        localScale: 1,
      ),
      const Bone(
        id: 'arm',
        name: 'Arm',
        parentId: 'root',
        spritePath: null,
        localPosition: Offset(120, 0),
        localRotation: 0,
        localScale: 1,
      ),
    ];
    _baseRotations = <String, double>{
      for (final b in _bones) b.id: b.localRotation,
    };
    _editedRotations = Map<String, double>.from(_baseRotations);
    _rotationKeyframes = <String, Map<double, double>>{
      'arm': <double, double>{0: 0, 1000: 1.5, 2000: 0.5, 3000: -0.8, 4000: 0},
    };
    _selectedBoneId = 'arm';

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _timelineDurationMs.toInt()),
    );
    _animationController.addListener(_onPlaybackTick);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('kindling_editor - MVP'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              child: FilledButton.tonalIcon(
                onPressed: _isPlaying ? _stopPlayback : _startPlayback,
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                label: Text(_isPlaying ? 'Pausar' : 'Play'),
              ),
            ),
          ),
          if (_isPlaying)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  '${(_playbackTimeMs / 1000).toStringAsFixed(2)}s / ${(_timelineDurationMs / 1000).toStringAsFixed(1)}s',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: FilledButton.tonal(
                onPressed: _showExportJson,
                child: const Text('Export JSON'),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                SizedBox(width: 280, child: _buildHierarchyPanel()),
                const VerticalDivider(width: 1),
                Expanded(child: _buildCanvasPanel()),
                const VerticalDivider(width: 1),
                SizedBox(width: 280, child: _buildInspectorPanel()),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(height: 240, child: _buildTimelinePanel()),
        ],
      ),
    );
  }

  void _startPlayback() {
    setState(() {
      _isPlaying = true;
      _playbackTimeMs = 0;
    });
    _animationController.reset();
    _animationController.forward();
  }

  void _stopPlayback() {
    _animationController.stop();
    setState(() {
      _isPlaying = false;
      _playbackTimeMs = 0;
    });
    _applyFrameToEditorPose(0);
  }

  void _onPlaybackTick() {
    if (_isPlaying) {
      setState(() {
        _playbackTimeMs = _animationController.value * _timelineDurationMs;
        _applyFrameToEditorPose(_playbackTimeMs);
      });
    }
  }

  Widget _buildHierarchyPanel() {
    final entries = _buildHierarchyEntries();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Hierarchy',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Adicionar filho ao selecionado',
                onPressed: _addBone,
                icon: const Icon(Icons.add),
              ),
              IconButton(
                tooltip: 'Deletar osso selecionado',
                onPressed: _selectedBoneId == null ? null : _deleteSelectedBone,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final selected = entry.bone.id == _selectedBoneId;
              final parentName = entry.bone.parentId == null
                  ? 'none'
                  : _boneNameById(entry.bone.parentId!) ?? 'unknown';
              final childCount = _bones
                  .where((bone) => bone.parentId == entry.bone.id)
                  .length;
              return ListTile(
                dense: true,
                selected: selected,
                leading: Icon(
                  entry.bone.parentId == null
                      ? Icons.account_tree
                      : Icons.subdirectory_arrow_right,
                  size: 18,
                ),
                title: Padding(
                  padding: EdgeInsets.only(left: entry.depth * 14.0),
                  child: Text(_hierarchyLabel(entry.depth, entry.bone.name)),
                ),
                subtitle: Text(
                  'id: ${entry.bone.id} | parent: $parentName | children: $childCount',
                ),
                onTap: () {
                  setState(() {
                    _selectedBoneId = entry.bone.id;
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _hierarchyLabel(int depth, String name) {
    if (depth == 0) {
      return name;
    }

    final buffer = StringBuffer();
    for (var i = 1; i < depth; i++) {
      buffer.write('|   ');
    }
    buffer.write('|-- ');
    buffer.write(name);
    return buffer.toString();
  }

  String? _boneNameById(String id) {
    for (final bone in _bones) {
      if (bone.id == id) {
        return bone.name;
      }
    }
    return null;
  }

  Widget _buildInspectorPanel() {
    final selectedBone = _selectedBone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Inspector',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const Divider(height: 1),
        if (selectedBone == null)
          const Expanded(
            child: Center(child: Text('Selecione um osso para editar.')),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: <Widget>[
                Text('Nome: ${selectedBone.name}'),
                const SizedBox(height: 8),
                Text('ID: ${selectedBone.id}'),
                const SizedBox(height: 16),
                Text(
                  'Rotacao: ${(_editedRotations[selectedBone.id] ?? 0).toStringAsFixed(3)} rad',
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: ValueKey<String>(
                    'rotation_${selectedBone.id}_${_selectedFrameMs.toStringAsFixed(0)}',
                  ),
                  initialValue: (_editedRotations[selectedBone.id] ?? 0)
                      .toStringAsFixed(3),
                  enabled: !_isPlaying,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Rotacao manual (rad)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onFieldSubmitted: _setSelectedBoneRotationFromInput,
                ),
                const SizedBox(height: 16),
                Text(
                  'Comprimento: ${selectedBone.length.toStringAsFixed(1)}px',
                ),
                Slider(
                  value: selectedBone.length,
                  min: 10,
                  max: 300,
                  onChanged: (value) {
                    _updateSelectedBoneLength(value);
                  },
                ),
                const SizedBox(height: 16),
                Text('Sprite: ${selectedBone.spritePath ?? 'nenhum'}'),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: _editSelectedBoneSpritePath,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(
                    selectedBone.spritePath == null
                        ? 'Definir Sprite PNG'
                        : 'Alterar Sprite PNG',
                  ),
                ),
                if (selectedBone.spritePath != null) ...<Widget>[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _clearSelectedBoneSpritePath,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remover Sprite'),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Dica: use caminho relativo ao arquivo JSON exportado. No runtime/example, as imagens serao procuradas na mesma pasta base escolhida na importacao.',
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCanvasPanel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanStart: (details) =>
              _onCanvasPanStart(details.localPosition, constraints.biggest),
          onPanUpdate: (details) =>
              _onCanvasPanUpdate(details.localPosition, constraints.biggest),
          onPanEnd: (_) => _onCanvasPanEnd(),
          child: CustomPaint(
            painter: _SkeletonPainter(
              bones: _bones,
              editedRotations: _editedRotations,
              selectedBoneId: _selectedBoneId,
              canvasSize: constraints.biggest,
              boneImages: _boneImages,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }

  Widget _buildTimelinePanel() {
    final selectedBoneId = _selectedBoneId;
    final selectedBoneRotation = selectedBoneId == null
        ? null
        : _editedRotations[selectedBoneId];
    final rulerMarks = _buildTimelineRulerMarks();
    final tracks = _buildTimelineTracks();
    final currentTimeMs = _isPlaying ? _playbackTimeMs : _selectedFrameMs;
    final playheadX = _timeToPixels(currentTimeMs);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text(
                'Timeline',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 12),
              Text('Tempo: ${currentTimeMs.toStringAsFixed(0)} ms'),
              const SizedBox(width: 12),
              SizedBox(
                width: 130,
                child: TextFormField(
                  key: ValueKey<String>(
                    'duration_${_timelineDurationMs.toStringAsFixed(0)}',
                  ),
                  initialValue: (_timelineDurationMs / 1000).toStringAsFixed(2),
                  enabled: !_isPlaying,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Duracao (s)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onFieldSubmitted: _setTimelineDurationFromSecondsInput,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _isPlaying || selectedBoneId == null
                    ? null
                    : _saveRotationKeyframe,
                icon: const Icon(Icons.key),
                label: const Text('Salvar Rotacao'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 180,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(
                        right: BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Column(
                      children: <Widget>[
                        Container(
                          height: 32,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: const Text(
                            'Tracks',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Divider(height: 1),
                        const Expanded(child: SizedBox.shrink()),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) {
                          if (_isPlaying) return;
                          final localX = details.localPosition.dx;
                          setState(() {
                            _selectedFrameMs = _snapTime(_pixelsToTime(localX));
                            _applyFrameToEditorPose(_selectedFrameMs);
                          });
                        },
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: _timeToPixels(_timelineDurationMs) + 80,
                            child: Stack(
                              children: <Widget>[
                                Column(
                                  children: <Widget>[
                                    SizedBox(
                                      height: 32,
                                      child: CustomPaint(
                                        size: Size(
                                          _timeToPixels(_timelineDurationMs) +
                                              80,
                                          32,
                                        ),
                                        painter: _TimelineRulerPainter(
                                          marks: rulerMarks,
                                          selectedFrameMs: _selectedFrameMs,
                                          pixelsPerSecond: _pixelsPerSecond,
                                        ),
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: tracks.length,
                                        itemBuilder: (context, index) {
                                          final track = tracks[index];
                                          final selected =
                                              track.bone.id == _selectedBoneId;
                                          return SizedBox(
                                            height: 44,
                                            child: Row(
                                              children: <Widget>[
                                                SizedBox(
                                                  width: 180,
                                                  child: InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        _selectedBoneId =
                                                            track.bone.id;
                                                      });
                                                    },
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                          ),
                                                      color: selected
                                                          ? const Color(
                                                              0xFFCCFBF1,
                                                            )
                                                          : const Color(
                                                              0xFFF8FAFC,
                                                            ),
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      child: Text(
                                                        '${track.bone.name}  ·  Rotacao',
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: _timeToPixels(
                                                        _timelineDurationMs,
                                                      ) +
                                                      80,
                                                  child: CustomPaint(
                                                    size: Size(
                                                      _timeToPixels(
                                                            _timelineDurationMs,
                                                          ) +
                                                          80,
                                                      44,
                                                    ),
                                                    painter:
                                                        _TimelineTrackPainter(
                                                          keyframesMs: track
                                                              .keyframesMs,
                                                          selected: selected,
                                                          durationMs:
                                                              _timelineDurationMs,
                                                          pixelsPerSecond:
                                                              _pixelsPerSecond,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                Positioned(
                                  left: playheadX - 1,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 2,
                                    color: const Color(0xFFEF4444),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (selectedBoneId != null)
            Text(
              'Osso selecionado: $selectedBoneId | Rotacao atual: '
              '${(selectedBoneRotation ?? 0).toStringAsFixed(3)} rad',
            )
          else
            const Text('Selecione um osso na hierarquia para editar.'),
        ],
      ),
    );
  }

  void _addBone() {
    final parentId = _selectedBoneId;
    final id = 'bone_${_nextBoneIndex++}';
    final labelIndex = _nextBoneIndex - 1;
    Bone? parentBone;
    if (parentId != null) {
      for (final bone in _bones) {
        if (bone.id == parentId) {
          parentBone = bone;
          break;
        }
      }
    }
    final offsetX = parentBone == null
        ? 80.0
        : parentBone.length * parentBone.localScale;

    setState(() {
      _bones = <Bone>[
        ..._bones,
        Bone(
          id: id,
          name: 'Bone $labelIndex',
          parentId: parentId,
          spritePath: null,
          localPosition: Offset(offsetX, 0),
          localRotation: 0,
          localScale: 1,
        ),
      ];
      _baseRotations[id] = 0;
      _editedRotations[id] = 0;
      _selectedBoneId = parentId ?? id;
    });
  }

  void _deleteSelectedBone() {
    final selectedBoneId = _selectedBoneId;
    if (selectedBoneId == null) {
      return;
    }

    final byParent = <String?, List<Bone>>{};
    for (final bone in _bones) {
      byParent.putIfAbsent(bone.parentId, () => <Bone>[]).add(bone);
    }

    final idsToDelete = <String>{};
    void collect(String boneId) {
      idsToDelete.add(boneId);
      for (final child in byParent[boneId] ?? const <Bone>[]) {
        collect(child.id);
      }
    }

    collect(selectedBoneId);
    if (idsToDelete.length == _bones.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao e possivel remover todos os ossos.')),
      );
      return;
    }

    setState(() {
      _bones = _bones.where((bone) => !idsToDelete.contains(bone.id)).toList();
      for (final id in idsToDelete) {
        _baseRotations.remove(id);
        _editedRotations.remove(id);
        _rotationKeyframes.remove(id);
        _boneImages.remove(id);
      }
      _selectedBoneId = _bones.isNotEmpty ? _bones.first.id : null;
    });
  }

  void _saveRotationKeyframe() {
    final selectedBoneId = _selectedBoneId;
    if (selectedBoneId == null) {
      return;
    }

    final value = _editedRotations[selectedBoneId] ?? 0;
    setState(() {
      _rotationKeyframes.putIfAbsent(
        selectedBoneId,
        () => <double, double>{},
      )[_selectedFrameMs] = value;
    });
  }

  void _updateSelectedBoneLength(double length) {
    final selectedBoneId = _selectedBoneId;
    if (selectedBoneId == null) {
      return;
    }

    setState(() {
      final updatedBones = _bones
          .map(
            (bone) => bone.id == selectedBoneId
                ? bone.copyWith(length: length)
                : bone,
          )
          .toList();
      _bones = _alignChildrenToParentTips(updatedBones);
    });
  }

  List<Bone> _alignChildrenToParentTips(List<Bone> bones) {
    final byId = <String, Bone>{for (final bone in bones) bone.id: bone};
    return bones
        .map((bone) {
          final parentId = bone.parentId;
          if (parentId == null) {
            return bone;
          }

          final parent = byId[parentId];
          if (parent == null) {
            return bone;
          }

          final tipX = parent.length * parent.localScale;
          return bone.copyWith(localPosition: Offset(tipX, 0));
        })
        .toList(growable: false);
  }

  void _setSelectedBoneRotationFromInput(String value) {
    final selectedBoneId = _selectedBoneId;
    if (selectedBoneId == null) {
      return;
    }

    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null) {
      return;
    }

    setState(() {
      _editedRotations[selectedBoneId] = parsed;
    });
  }

  void _setTimelineDurationFromSecondsInput(String value) {
    final seconds = double.tryParse(value.replaceAll(',', '.'));
    if (seconds == null) {
      return;
    }

    final durationMs = (seconds * 1000).clamp(250.0, 120000.0);
    setState(() {
      _timelineDurationMs = durationMs;
      _selectedFrameMs = _selectedFrameMs.clamp(0.0, _timelineDurationMs);
      _playbackTimeMs = _playbackTimeMs.clamp(0.0, _timelineDurationMs);
      _animationController.duration = Duration(
        milliseconds: _timelineDurationMs.toInt(),
      );
    });
  }

  Bone? get _selectedBone {
    final selectedId = _selectedBoneId;
    if (selectedId == null) {
      return null;
    }

    for (final bone in _bones) {
      if (bone.id == selectedId) {
        return bone;
      }
    }
    return null;
  }

  Future<void> _editSelectedBoneSpritePath() async {
    final bone = _selectedBone;
    if (bone == null) {
      return;
    }

    final controller = TextEditingController(text: bone.spritePath ?? '');
    final path = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Sprite PNG de ${bone.name}'),
          content: SizedBox(
            width: 520,
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Ex: arm.png ou sprites/arm.png',
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    if (!mounted || path == null) {
      return;
    }

    final normalizedPath = path.isEmpty ? null : path;
    await _updateBoneSpritePath(bone.id, normalizedPath);
  }

  Future<void> _clearSelectedBoneSpritePath() async {
    final bone = _selectedBone;
    if (bone == null) {
      return;
    }

    await _updateBoneSpritePath(bone.id, null);
  }

  Future<void> _updateBoneSpritePath(String boneId, String? spritePath) async {
    final updatedBones = _bones
        .map(
          (bone) =>
              bone.id == boneId ? bone.copyWith(spritePath: spritePath) : bone,
        )
        .toList(growable: false);

    ui.Image? loadedImage;
    if (spritePath != null) {
      loadedImage = await _tryLoadImageFromPath(spritePath);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _bones = updatedBones;
      if (loadedImage != null) {
        _boneImages[boneId] = loadedImage;
      } else {
        _boneImages.remove(boneId);
      }
    });
  }

  Future<ui.Image?> _tryLoadImageFromPath(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return null;
      }
      final bytes = await file.readAsBytes();
      return decodeImageFromList(bytes);
    } catch (_) {
      return null;
    }
  }

  void _applyFrameToEditorPose(double frameMs) {
    for (final bone in _bones) {
      final keyframes = _rotationKeyframes[bone.id] ?? const <double, double>{};
      _editedRotations[bone.id] = _sampleRotationAtTime(
        timeMs: frameMs,
        keyframes: keyframes,
        fallback: _baseRotations[bone.id] ?? 0,
      );
    }
  }

  double _sampleRotationAtTime({
    required double timeMs,
    required Map<double, double> keyframes,
    required double fallback,
  }) {
    if (keyframes.isEmpty) {
      return fallback;
    }

    final sorted = keyframes.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (timeMs <= sorted.first.key) {
      return sorted.first.value;
    }
    if (timeMs >= sorted.last.key) {
      return sorted.last.value;
    }

    for (var index = 0; index < sorted.length - 1; index++) {
      final a = sorted[index];
      final b = sorted[index + 1];
      if (timeMs >= a.key && timeMs <= b.key) {
        final t = (timeMs - a.key) / (b.key - a.key);
        return ui.lerpDouble(a.value, b.value, t) ?? fallback;
      }
    }

    return fallback;
  }

  void _onCanvasPanStart(Offset localPosition, Size canvasSize) {
    final selectedBoneId = _selectedBoneId;
    if (selectedBoneId == null) {
      return;
    }

    final pivot = _computeBoneGlobalPosition(selectedBoneId, canvasSize);
    if (pivot == null) {
      return;
    }

    _dragPivot = pivot;
    _dragStartPointerAngle = _angleFromPivot(pivot, localPosition);
    _dragStartBoneRotation = _editedRotations[selectedBoneId] ?? 0;
  }

  void _onCanvasPanUpdate(Offset localPosition, Size canvasSize) {
    final selectedBoneId = _selectedBoneId;
    final pivot = _dragPivot;
    final startAngle = _dragStartPointerAngle;
    final startRotation = _dragStartBoneRotation;
    if (selectedBoneId == null ||
        pivot == null ||
        startAngle == null ||
        startRotation == null) {
      return;
    }

    final currentAngle = _angleFromPivot(pivot, localPosition);
    final delta = _normalizeAngle(currentAngle - startAngle);

    setState(() {
      _editedRotations[selectedBoneId] = startRotation + delta;
    });
  }

  void _onCanvasPanEnd() {
    _dragPivot = null;
    _dragStartPointerAngle = null;
    _dragStartBoneRotation = null;
  }

  double _angleFromPivot(Offset pivot, Offset pointer) {
    return math.atan2(pointer.dy - pivot.dy, pointer.dx - pivot.dx);
  }

  double _normalizeAngle(double angle) {
    var result = angle;
    while (result > math.pi) {
      result -= 2 * math.pi;
    }
    while (result < -math.pi) {
      result += 2 * math.pi;
    }
    return result;
  }

  Offset? _computeBoneGlobalPosition(String boneId, Size canvasSize) {
    final transforms = _computeGlobalTransforms();
    final transform = transforms[boneId];
    if (transform == null) {
      return null;
    }

    final world = transform.transform3(vm.Vector3.zero());
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    return center + Offset(world.x, world.y);
  }

  Map<String, vm.Matrix4> _computeGlobalTransforms() {
    final overrides = <String, BonePose>{
      for (final bone in _bones)
        bone.id: BonePose(
          localPosition: bone.localPosition,
          localRotation: _editedRotations[bone.id] ?? bone.localRotation,
          localScale: bone.localScale,
        ),
    };

    return SkeletonMath.computeGlobalTransforms(
      bones: _bones,
      overrides: overrides,
    );
  }

  List<_HierarchyEntry> _buildHierarchyEntries() {
    final byParent = <String?, List<Bone>>{};
    for (final bone in _bones) {
      byParent.putIfAbsent(bone.parentId, () => <Bone>[]).add(bone);
    }

    final result = <_HierarchyEntry>[];

    void visit(String? parentId, int depth) {
      final children = byParent[parentId] ?? const <Bone>[];
      for (final child in children) {
        result.add(_HierarchyEntry(child, depth));
        visit(child.id, depth + 1);
      }
    }

    visit(null, 0);
    return result;
  }

  void _showExportJson() {
    final project = _buildExportProject();
    final jsonString = const JsonEncoder.withIndent(
      '  ',
    ).convert(project.toJson());
    final controller = TextEditingController(text: jsonString);
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('SkeletonProject JSON'),
          content: SizedBox(
            width: 760,
            child: TextField(
              controller: controller,
              readOnly: true,
              maxLines: 24,
              minLines: 16,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ),
          actions: <Widget>[
            FilledButton.tonalIcon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: jsonString));
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('JSON copiado para a area de transferencia.'),
                  ),
                );
              },
              icon: const Icon(Icons.copy_all),
              label: const Text('Copiar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  SkeletonProject _buildExportProject() {
    final exportedBones = _bones
        .map(
          (bone) => bone.copyWith(
            spritePath: bone.spritePath,
            localRotation: _editedRotations[bone.id] ?? bone.localRotation,
          ),
        )
        .toList(growable: false);

    final boneAnimations = <BoneAnimation>[];
    for (final bone in _bones) {
      final keyByFrame = _rotationKeyframes[bone.id];
      if (keyByFrame == null || keyByFrame.isEmpty) {
        continue;
      }

      final keys =
          keyByFrame.entries
              .map((entry) => Keyframe(time: entry.key, value: entry.value))
              .toList()
            ..sort((a, b) => a.time.compareTo(b.time));

      boneAnimations.add(
        BoneAnimation(
          boneId: bone.id,
          rotationKeyframes: keys,
          translationKeyframes: const <Keyframe>[],
        ),
      );
    }

    final clip = AnimationClip(
      name: 'clip_01',
      duration: _timelineDurationMs,
      boneAnimations: boneAnimations,
    );

    return SkeletonProject(
      bones: exportedBones,
      animationClips: <AnimationClip>[clip],
    );
  }

  List<double> _buildTimelineRulerMarks() {
    final marks = <double>[];
    for (
      var value = 0.0;
      value <= _timelineDurationMs;
      value += _timelineStepMs
    ) {
      marks.add(value);
    }
    return marks;
  }

  List<_TimelineTrack> _buildTimelineTracks() {
    return _bones
        .map(
          (bone) => _TimelineTrack(
            bone: bone,
            keyframesMs: [...?_rotationKeyframes[bone.id]?.keys]..sort(),
          ),
        )
        .toList(growable: false);
  }

  double _timeToPixels(double timeMs) {
    return (timeMs / 1000.0) * _pixelsPerSecond;
  }

  double _pixelsToTime(double pixels) {
    return (pixels / _pixelsPerSecond) * 1000.0;
  }

  double _snapTime(double timeMs) {
    final clamped = timeMs.clamp(0.0, _timelineDurationMs);
    return (clamped / _timelineStepMs).roundToDouble() * _timelineStepMs;
  }
}

class _HierarchyEntry {
  const _HierarchyEntry(this.bone, this.depth);

  final Bone bone;
  final int depth;
}

class _SkeletonPainter extends CustomPainter {
  const _SkeletonPainter({
    required this.bones,
    required this.editedRotations,
    required this.selectedBoneId,
    required this.canvasSize,
    required this.boneImages,
  });

  final List<Bone> bones;
  final Map<String, double> editedRotations;
  final String? selectedBoneId;
  final Size canvasSize;
  final Map<String, ui.Image> boneImages;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);

    final overrides = <String, BonePose>{
      for (final bone in bones)
        bone.id: BonePose(
          localPosition: bone.localPosition,
          localRotation: editedRotations[bone.id] ?? bone.localRotation,
          localScale: bone.localScale,
        ),
    };

    final transforms = SkeletonMath.computeGlobalTransforms(
      bones: bones,
      overrides: overrides,
    );
    final byId = <String, Bone>{for (final bone in bones) bone.id: bone};

    final gridPaint = Paint()..color = const Color(0xFFEEF2F6);
    for (var x = 0.0; x < size.width; x += 32) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint..strokeWidth = 0.5,
      );
    }
    for (var y = 0.0; y < size.height; y += 32) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint..strokeWidth = 0.5,
      );
    }

    for (final bone in bones) {
      final transform = transforms[bone.id];
      if (transform == null) {
        continue;
      }

      final origin = transform.transform3(vm.Vector3.zero());
      final tip = transform.transform3(
        vm.Vector3(bone.length * bone.localScale, 0, 0),
      );

      final originOffset = center + Offset(origin.x, origin.y);
      final tipOffset = center + Offset(tip.x, tip.y);

      final selected = bone.id == selectedBoneId;
      final linePaint = Paint()
        ..color = selected ? const Color(0xFF0F766E) : const Color(0xFF334155)
        ..strokeWidth = selected ? 5 : 3
        ..strokeCap = StrokeCap.round;

      final image = boneImages[bone.id];
      if (image != null) {
        canvas.save();
        canvas.translate(originOffset.dx, originOffset.dy);
        canvas.rotate(
          math.atan2(
            tipOffset.dy - originOffset.dy,
            tipOffset.dx - originOffset.dx,
          ),
        );
        final src = Rect.fromLTWH(
          0,
          0,
          image.width.toDouble(),
          image.height.toDouble(),
        );
        final spriteWidth = bone.length * bone.localScale;
        final spriteHeight = spriteWidth * 0.5;
        final dst = Rect.fromCenter(
          center: Offset(spriteWidth / 2, 0),
          width: spriteWidth,
          height: spriteHeight,
        );
        canvas.drawImageRect(image, src, dst, Paint());
        canvas.restore();
      }

      canvas.drawLine(originOffset, tipOffset, linePaint);

      if (bone.parentId != null) {
        final parentTransform = transforms[bone.parentId!];
        if (parentTransform != null) {
          final parentOrigin = parentTransform.transform3(vm.Vector3.zero());
          final parentOffset = center + Offset(parentOrigin.x, parentOrigin.y);
          canvas.drawLine(
            parentOffset,
            originOffset,
            Paint()
              ..color = const Color(0xFF94A3B8)
              ..strokeWidth = 1.2,
          );
        }
      }

      canvas.drawCircle(
        originOffset,
        selected ? 8 : 6,
        Paint()
          ..color = selected
              ? const Color(0xFF14B8A6)
              : const Color(0xFF64748B),
      );

      final textSpan = TextSpan(
        text: byId[bone.id]?.name ?? bone.id,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, originOffset + const Offset(10, -24));
    }
  }

  @override
  bool shouldRepaint(covariant _SkeletonPainter oldDelegate) {
    return oldDelegate.bones != bones ||
        oldDelegate.editedRotations != editedRotations ||
        oldDelegate.selectedBoneId != selectedBoneId ||
        oldDelegate.canvasSize != canvasSize ||
        oldDelegate.boneImages != boneImages;
  }
}

class _TimelineTrack {
  const _TimelineTrack({required this.bone, required this.keyframesMs});

  final Bone bone;
  final List<double> keyframesMs;
}

class _TimelineRulerPainter extends CustomPainter {
  const _TimelineRulerPainter({
    required this.marks,
    required this.selectedFrameMs,
    required this.pixelsPerSecond,
  });

  final List<double> marks;
  final double selectedFrameMs;
  final double pixelsPerSecond;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFFF8FAFC);
    canvas.drawRect(Offset.zero & size, background);

    for (final mark in marks) {
      final x = (mark / 1000.0) * pixelsPerSecond;
      final isSecond = mark % 1000 == 0;
      canvas.drawLine(
        Offset(x, isSecond ? 8 : 16),
        Offset(x, size.height),
        Paint()
          ..color = const Color(0xFF94A3B8)
          ..strokeWidth = isSecond ? 1.4 : 1,
      );

      if (isSecond) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${(mark / 1000).toStringAsFixed(0)}s',
            style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + 4, 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineRulerPainter oldDelegate) {
    return oldDelegate.marks != marks ||
        oldDelegate.selectedFrameMs != selectedFrameMs ||
        oldDelegate.pixelsPerSecond != pixelsPerSecond;
  }
}

class _TimelineTrackPainter extends CustomPainter {
  const _TimelineTrackPainter({
    required this.keyframesMs,
    required this.selected,
    required this.durationMs,
    required this.pixelsPerSecond,
  });

  final List<double> keyframesMs;
  final bool selected;
  final double durationMs;
  final double pixelsPerSecond;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = selected ? const Color(0xFFF0FDFA) : const Color(0xFFFFFFFF),
    );

    for (var x = 0.0; x <= size.width; x += pixelsPerSecond / 4) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = const Color(0xFFE2E8F0)
          ..strokeWidth = 1,
      );
    }

    for (final keyframeMs in keyframesMs) {
      final x = (keyframeMs / 1000.0) * pixelsPerSecond;
      final path = Path()
        ..moveTo(x, size.height / 2 - 8)
        ..lineTo(x + 8, size.height / 2)
        ..lineTo(x, size.height / 2 + 8)
        ..lineTo(x - 8, size.height / 2)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = selected
              ? const Color(0xFF0F766E)
              : const Color(0xFF6366F1),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineTrackPainter oldDelegate) {
    return oldDelegate.keyframesMs != keyframesMs ||
        oldDelegate.selected != selected ||
        oldDelegate.durationMs != durationMs ||
        oldDelegate.pixelsPerSecond != pixelsPerSecond;
  }
}
