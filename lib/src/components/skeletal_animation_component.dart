import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';

import '../math/skeleton_math.dart';
import '../models/skeletal_models.dart';

class SkeletalAnimationComponent extends PositionComponent {
  SkeletalAnimationComponent({
    required this.project,
    required this.boneSprites,
    this.boneSizes = const <String, Vector2>{},
    String? initialClip,
    super.position,
    super.size,
    super.anchor,
  }) : _currentClipName = initialClip;

  final SkeletonProject project;
  final Map<String, Sprite> boneSprites;
  final Map<String, Vector2> boneSizes;

  String? _currentClipName;
  double _currentTimeMs = 0.0;

  String? _blendTargetClipName;
  double _blendTargetTimeMs = 0.0;
  double _blendDurationMs = 0.0;
  double _blendElapsedMs = 0.0;

  final Map<String, BonePose> _animatedPoseByBone = <String, BonePose>{};
  Map<String, Matrix4> _globalTransforms = const <String, Matrix4>{};

  void play(
    String clipName, {
    bool restart = false,
    double blendDurationMs = 0.0,
  }) {
    if (_currentClipName == clipName && !restart) {
      return;
    }

    final nextClip = project.findClipByName(clipName);
    if (nextClip == null) {
      return;
    }

    final hasCurrent = _currentClip != null;
    final shouldBlend = hasCurrent && blendDurationMs > 0.0;

    if (!shouldBlend) {
      _currentClipName = clipName;
      _currentTimeMs = restart ? 0.0 : _currentTimeMs;
      _clearBlendState();
      return;
    }

    _blendTargetClipName = clipName;
    _blendTargetTimeMs = 0.0;
    _blendDurationMs = blendDurationMs;
    _blendElapsedMs = 0.0;
  }

  AnimationClip? get _currentClip {
    final clipName = _currentClipName;
    if (clipName == null && project.animationClips.isNotEmpty) {
      return project.animationClips.first;
    }
    if (clipName == null) {
      return null;
    }
    return project.findClipByName(clipName);
  }

  AnimationClip? get _blendTargetClip {
    final clipName = _blendTargetClipName;
    if (clipName == null) {
      return null;
    }
    return project.findClipByName(clipName);
  }

  @override
  void update(double dt) {
    super.update(dt);

    final clip = _currentClip;
    if (clip == null || clip.duration <= 0.0) {
      _animatedPoseByBone
        ..clear()
        ..addEntries(
          project.bones.map(
            (bone) =>
                MapEntry<String, BonePose>(bone.id, BonePose.fromBone(bone)),
          ),
        );
      _globalTransforms = SkeletonMath.computeGlobalTransforms(
        bones: project.bones,
        overrides: _animatedPoseByBone,
      );
      return;
    }

    _currentTimeMs = (_currentTimeMs + (dt * 1000.0)) % clip.duration;

    final currentPose = _samplePoseForClip(clip, _currentTimeMs);

    _animatedPoseByBone
      ..clear()
      ..addAll(currentPose);

    final targetClip = _blendTargetClip;
    if (targetClip != null && targetClip.duration > 0.0) {
      _blendTargetTimeMs =
          (_blendTargetTimeMs + (dt * 1000.0)) % targetClip.duration;
      _blendElapsedMs += dt * 1000.0;

      final blendT = (_blendElapsedMs / _blendDurationMs).clamp(0.0, 1.0);
      final targetPose = _samplePoseForClip(targetClip, _blendTargetTimeMs);

      for (final bone in project.bones) {
        final fromPose = currentPose[bone.id] ?? BonePose.fromBone(bone);
        final toPose = targetPose[bone.id] ?? BonePose.fromBone(bone);
        _animatedPoseByBone[bone.id] = _blendPose(
          from: fromPose,
          to: toPose,
          t: blendT,
        );
      }

      if (blendT >= 1.0) {
        _currentClipName = _blendTargetClipName;
        _currentTimeMs = _blendTargetTimeMs;
        _clearBlendState();
      }
    }

    _globalTransforms = SkeletonMath.computeGlobalTransforms(
      bones: project.bones,
      overrides: _animatedPoseByBone,
    );
  }

  void _clearBlendState() {
    _blendTargetClipName = null;
    _blendTargetTimeMs = 0.0;
    _blendDurationMs = 0.0;
    _blendElapsedMs = 0.0;
  }

  Map<String, BonePose> _samplePoseForClip(AnimationClip clip, double timeMs) {
    final animationByBone = <String, BoneAnimation>{
      for (final anim in clip.boneAnimations) anim.boneId: anim,
    };

    final result = <String, BonePose>{};

    for (final bone in project.bones) {
      final boneAnimation = animationByBone[bone.id];

      final animatedPosition = boneAnimation == null
          ? bone.localPosition
          : _sampleTranslation(
              keyframes: boneAnimation.translationKeyframes,
              currentTimeMs: timeMs,
              fallback: bone.localPosition,
            );

      final animatedRotation = boneAnimation == null
          ? bone.localRotation
          : _sampleRotation(
              keyframes: boneAnimation.rotationKeyframes,
              currentTimeMs: timeMs,
              fallback: bone.localRotation,
            );

      result[bone.id] = BonePose(
        localPosition: animatedPosition,
        localRotation: animatedRotation,
        localScale: bone.localScale,
      );
    }

    return result;
  }

  BonePose _blendPose({
    required BonePose from,
    required BonePose to,
    required double t,
  }) {
    return BonePose(
      localPosition: Offset(
        lerpDouble(from.localPosition.dx, to.localPosition.dx, t) ??
            from.localPosition.dx,
        lerpDouble(from.localPosition.dy, to.localPosition.dy, t) ??
            from.localPosition.dy,
      ),
      localRotation: interpolateRotationLinear(
        from: from.localRotation,
        to: to.localRotation,
        t: t,
      ),
      localScale:
          lerpDouble(from.localScale, to.localScale, t) ?? from.localScale,
    );
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    for (final bone in project.bones) {
      final sprite = boneSprites[bone.id];
      if (sprite == null) {
        continue;
      }

      final transform = _globalTransforms[bone.id] ?? Matrix4.identity();

      canvas.save();
      canvas.transform(Float64List.fromList(transform.storage));
      sprite.render(
        canvas,
        position: Vector2.zero(),
        size: boneSizes[bone.id],
        anchor: Anchor.center,
      );
      canvas.restore();
    }
  }

  static double _sampleRotation({
    required List<Keyframe> keyframes,
    required double currentTimeMs,
    required double fallback,
  }) {
    if (keyframes.isEmpty) {
      return fallback;
    }

    final sorted = [...keyframes]..sort((a, b) => a.time.compareTo(b.time));
    if (sorted.length == 1) {
      final value = sorted.first.value;
      return value is num ? value.toDouble() : fallback;
    }

    if (currentTimeMs <= sorted.first.time) {
      final value = sorted.first.value;
      return value is num ? value.toDouble() : fallback;
    }

    if (currentTimeMs >= sorted.last.time) {
      final value = sorted.last.value;
      return value is num ? value.toDouble() : fallback;
    }

    for (var index = 0; index < sorted.length - 1; index++) {
      final a = sorted[index];
      final b = sorted[index + 1];
      if (currentTimeMs >= a.time && currentTimeMs <= b.time) {
        final aValue = a.value;
        final bValue = b.value;

        if (aValue is! num || bValue is! num) {
          return fallback;
        }

        final t = (currentTimeMs - a.time) / (b.time - a.time);
        return lerpDouble(aValue.toDouble(), bValue.toDouble(), t) ?? fallback;
      }
    }

    return fallback;
  }

  static Offset _sampleTranslation({
    required List<Keyframe> keyframes,
    required double currentTimeMs,
    required Offset fallback,
  }) {
    if (keyframes.isEmpty) {
      return fallback;
    }

    final sorted = [...keyframes]..sort((a, b) => a.time.compareTo(b.time));

    if (sorted.length == 1) {
      return _decodeOffset(sorted.first.value, fallback);
    }

    if (currentTimeMs <= sorted.first.time) {
      return _decodeOffset(sorted.first.value, fallback);
    }

    if (currentTimeMs >= sorted.last.time) {
      return _decodeOffset(sorted.last.value, fallback);
    }

    for (var index = 0; index < sorted.length - 1; index++) {
      final a = sorted[index];
      final b = sorted[index + 1];
      if (currentTimeMs >= a.time && currentTimeMs <= b.time) {
        final aOffset = _decodeOffset(a.value, fallback);
        final bOffset = _decodeOffset(b.value, fallback);
        final t = (currentTimeMs - a.time) / (b.time - a.time);

        return Offset(
          lerpDouble(aOffset.dx, bOffset.dx, t) ?? fallback.dx,
          lerpDouble(aOffset.dy, bOffset.dy, t) ?? fallback.dy,
        );
      }
    }

    return fallback;
  }

  static Offset _decodeOffset(Object? value, Offset fallback) {
    if (value is Offset) {
      return value;
    }

    if (value is List<dynamic> && value.length == 2) {
      final x = value[0];
      final y = value[1];
      if (x is num && y is num) {
        return Offset(x.toDouble(), y.toDouble());
      }
    }

    if (value is Map<String, dynamic>) {
      final x = value['x'];
      final y = value['y'];
      if (x is num && y is num) {
        return Offset(x.toDouble(), y.toDouble());
      }
    }

    return fallback;
  }

  static double interpolateRotationLinear({
    required double from,
    required double to,
    required double t,
  }) {
    return lerpDouble(from, to, t) ?? from;
  }
}
