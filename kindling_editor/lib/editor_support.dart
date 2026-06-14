part of 'main.dart';

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

class _SpriteGroupDetailsDialog extends StatefulWidget {
  const _SpriteGroupDetailsDialog({
    required this.group,
    required this.onSpritesUpdated,
  });

  final SpriteGroup group;
  final Function(SpriteGroup) onSpritesUpdated;

  @override
  State<_SpriteGroupDetailsDialog> createState() =>
      _SpriteGroupDetailsDialogState();
}

class _SpriteGroupDetailsDialogState extends State<_SpriteGroupDetailsDialog> {
  late List<SpriteDefinition> _sprites;
  ui.Image? _previewImage;
  bool _previewLoading = true;

  @override
  void initState() {
    super.initState();
    _sprites = List<SpriteDefinition>.from(widget.group.sprites);
    _loadPreviewImage();
  }

  Future<void> _loadPreviewImage() async {
    try {
      final bytes = base64Decode(widget.group.imageBase64);
      final image = await decodeImageFromList(bytes);
      if (!mounted) {
        return;
      }
      setState(() {
        _previewImage = image;
        _previewLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _previewImage = null;
        _previewLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Sprite Group: ${widget.group.id}'),
      content: SizedBox(
        width: 920,
        height: 720,
        child: Column(
          children: <Widget>[
            _buildImagePreview(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Partes: ${_sprites.length}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Part'),
                  onPressed: _createNewPart,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            Expanded(
              child: _sprites.isEmpty
                  ? const Center(child: Text('No parts defined yet.'))
                  : ListView.separated(
                      itemCount: _sprites.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final sprite = _sprites[index];
                        return ListTile(
                          leading: const Icon(Icons.polyline),
                          title: Text(sprite.id),
                          subtitle: Text(
                            sprite.vertices.isEmpty
                                ? 'No vertices yet'
                                : '${sprite.vertices.length} vertices',
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: <Widget>[
                              IconButton(
                                tooltip: 'Edit vertices',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _editPart(index),
                              ),
                              IconButton(
                                tooltip: 'Delete part',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _removePart(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saveChanges,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    final image = _previewImage;
    return Container(
      height: 260,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: _previewLoading
          ? const Center(child: CircularProgressIndicator())
          : image == null
              ? const Center(child: Text('Could not decode image preview.'))
              : FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: image.width.toDouble(),
                    height: image.height.toDouble(),
                    child: RawImage(image: image),
                  ),
                ),
    );
  }

  Future<void> _createNewPart() async {
    final nextId = 'part_${_sprites.length + 1}';
    final result = await _openPartEditor(
      SpriteDefinition(id: nextId, vertices: const <Offset>[]),
    );
    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _sprites.add(result);
    });
  }

  Future<void> _editPart(int index) async {
    if (index < 0 || index >= _sprites.length) {
      return;
    }

    final result = await _openPartEditor(_sprites[index]);
    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _sprites[index] = result;
    });
  }

  Future<SpriteDefinition?> _openPartEditor(SpriteDefinition initialPart) {
    return showDialog<SpriteDefinition>(
      context: context,
      builder: (context) {
        return _SpritePartEditorDialog(
          group: widget.group,
          initialPart: initialPart,
        );
      },
    );
  }

  void _removePart(int index) {
    setState(() {
      _sprites.removeAt(index);
    });
  }

  void _saveChanges() {
    final updatedGroup = widget.group.copyWith(sprites: _sprites);
    widget.onSpritesUpdated(updatedGroup);
    Navigator.of(context).pop();
  }
}

class _SpritePartEditorDialog extends StatefulWidget {
  const _SpritePartEditorDialog({
    required this.group,
    required this.initialPart,
  });

  final SpriteGroup group;
  final SpriteDefinition initialPart;

  @override
  State<_SpritePartEditorDialog> createState() =>
      _SpritePartEditorDialogState();
}

class _SpritePartEditorDialogState extends State<_SpritePartEditorDialog> {
  late final TextEditingController _idController;
  late List<Offset> _vertices;
  ui.Image? _previewImage;
  bool _previewLoading = true;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.initialPart.id);
    _vertices = List<Offset>.from(widget.initialPart.vertices);
    _loadPreviewImage();
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _loadPreviewImage() async {
    try {
      final bytes = base64Decode(widget.group.imageBase64);
      final image = await decodeImageFromList(bytes);
      if (!mounted) {
        return;
      }
      setState(() {
        _previewImage = image;
        _previewLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _previewImage = null;
        _previewLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Part: ${widget.initialPart.id}'),
      content: SizedBox(
        width: 960,
        height: 760,
        child: Column(
          children: <Widget>[
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: 'Part id',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _previewLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _previewImage == null
                      ? const Center(child: Text('Could not decode image.'))
                      : _SpriteVertexEditor(
                          image: _previewImage!,
                          vertices: _vertices,
                          onAddVertex: (vertex) {
                            setState(() {
                              _vertices.add(vertex);
                            });
                          },
                          onUndo: _vertices.isEmpty
                              ? null
                              : () {
                                  setState(() {
                                    _vertices.removeLast();
                                  });
                                },
                          onClear: _vertices.isEmpty
                              ? null
                              : () {
                                  setState(() {
                                    _vertices.clear();
                                  });
                                },
                        ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Clique na imagem para adicionar vértices. Use Undo/Clear se precisar refazer.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final id = _idController.text.trim();
            if (id.isEmpty) {
              return;
            }
            Navigator.of(context).pop(
              SpriteDefinition(id: id, vertices: List<Offset>.from(_vertices)),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _SpriteVertexEditor extends StatelessWidget {
  const _SpriteVertexEditor({
    required this.image,
    required this.vertices,
    required this.onAddVertex,
    required this.onUndo,
    required this.onClear,
  });

  final ui.Image image;
  final List<Offset> vertices;
  final ValueChanged<Offset> onAddVertex;
  final VoidCallback? onUndo;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = constraints.biggest;
        final fit = applyBoxFit(
          BoxFit.contain,
          Size(image.width.toDouble(), image.height.toDouble()),
          bounds,
        );
        final destination = Alignment.center.inscribe(
          fit.destination,
          Offset.zero & bounds,
        );

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: <Widget>[
              Positioned.fromRect(
                rect: destination,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final local = details.localPosition;
                    final scaleX = fit.destination.width / image.width;
                    final scaleY = fit.destination.height / image.height;
                    final imageX = local.dx / scaleX;
                    final imageY = local.dy / scaleY;
                    if (imageX < 0 || imageY < 0) {
                      return;
                    }
                    if (imageX > image.width || imageY > image.height) {
                      return;
                    }
                    onAddVertex(Offset(imageX, imageY));
                  },
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: RawImage(
                          image: image,
                          fit: BoxFit.fill,
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _SpriteVerticesPainter(
                            vertices: vertices,
                            imageSize: Size(
                              image.width.toDouble(),
                              image.height.toDouble(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Row(
                  children: <Widget>[
                    FilledButton.tonalIcon(
                      onPressed: onUndo,
                      icon: const Icon(Icons.undo),
                      label: const Text('Undo'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: onClear,
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SpriteVerticesPainter extends CustomPainter {
  const _SpriteVerticesPainter({
    required this.vertices,
    required this.imageSize,
  });

  final List<Offset> vertices;
  final Size imageSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (vertices.isEmpty) {
      return;
    }

    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;
    final scaledVertices = vertices
        .map((vertex) => Offset(vertex.dx * scaleX, vertex.dy * scaleY))
        .toList(growable: false);

    final fillPaint = Paint()
      ..color = const Color(0x3314B8A6)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = const Color(0xFF0F766E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final pointPaint = Paint()..color = const Color(0xFFF97316);

    if (scaledVertices.length >= 3) {
      final path = Path()..addPolygon(scaledVertices, true);
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);
    } else if (scaledVertices.length == 2) {
      canvas.drawLine(scaledVertices[0], scaledVertices[1], strokePaint);
    }

    for (var index = 0; index < scaledVertices.length; index++) {
      final vertex = scaledVertices[index];
      canvas.drawCircle(vertex, 5.5, pointPaint);
      canvas.drawCircle(
        vertex,
        2.5,
        Paint()..color = const Color(0xFFFFFFFF),
      );

      final labelPainter = TextPainter(
        text: TextSpan(
          text: '${index + 1}',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(canvas, vertex + const Offset(8, -18));
    }
  }

  @override
  bool shouldRepaint(covariant _SpriteVerticesPainter oldDelegate) {
    return oldDelegate.vertices != vertices ||
        oldDelegate.imageSize != imageSize;
  }
}
