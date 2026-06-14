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

  @override
  void initState() {
    super.initState();
    _sprites = List<SpriteDefinition>.from(widget.group.sprites);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Sprite Group: ${widget.group.id}'),
      content: SizedBox(
        width: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Partes: ${_sprites.length}'),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Part'),
                    onPressed: _addPart,
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: _sprites.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Icon(Icons.image_not_supported,
                              size: 48, color: Colors.grey),
                          const SizedBox(height: 8),
                          const Text('No parts defined'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _sprites.length,
                      itemBuilder: (context, index) {
                        final sprite = _sprites[index];
                        return ListTile(
                          leading: const Icon(Icons.rectangle),
                          title: Text(sprite.id),
                          subtitle:
                              Text('${sprite.vertices.length} vertices'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _removePart(index),
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

  void _addPart() {
    final id = 'part_${_sprites.length + 1}';
    setState(() {
      _sprites.add(SpriteDefinition(id: id, vertices: const <Offset>[]));
    });
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
