import 'dart:ui';

import 'package:flutter/foundation.dart';

@immutable
class Bone {
  const Bone({
    required this.id,
    required this.name,
    this.parentId,
    this.spritePath,
    required this.localPosition,
    required this.localRotation,
    required this.localScale,
    this.length = 70.0,
  });

  final String id;
  final String name;
  final String? parentId;
  final String? spritePath;
  final Offset localPosition;
  final double localRotation;
  final double localScale;
  final double length;

  Bone copyWith({
    String? id,
    String? name,
    String? parentId,
    String? spritePath,
    Offset? localPosition,
    double? localRotation,
    double? localScale,
    double? length,
  }) {
    return Bone(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      spritePath: spritePath ?? this.spritePath,
      localPosition: localPosition ?? this.localPosition,
      localRotation: localRotation ?? this.localRotation,
      localScale: localScale ?? this.localScale,
      length: length ?? this.length,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'parentId': parentId,
      'spritePath': spritePath,
      'localPosition': <String, dynamic>{
        'x': localPosition.dx,
        'y': localPosition.dy,
      },
      'localRotation': localRotation,
      'localScale': localScale,
      'length': length,
    };
  }

  factory Bone.fromJson(Map<String, dynamic> json) {
    final position =
        (json['localPosition'] as Map<String, dynamic>?) ??
        const <String, dynamic>{'x': 0.0, 'y': 0.0};

    return Bone(
      id: json['id'] as String,
      name: json['name'] as String,
      parentId: json['parentId'] as String?,
      spritePath: json['spritePath'] as String?,
      localPosition: Offset(
        (position['x'] as num).toDouble(),
        (position['y'] as num).toDouble(),
      ),
      localRotation: (json['localRotation'] as num).toDouble(),
      localScale: (json['localScale'] as num).toDouble(),
      length: (json['length'] as num?)?.toDouble() ?? 70.0,
    );
  }
}

@immutable
class Keyframe {
  const Keyframe({required this.time, required this.value});

  final double time;
  final Object? value;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'time': time, 'value': value};
  }

  factory Keyframe.fromJson(Map<String, dynamic> json) {
    return Keyframe(
      time: (json['time'] as num).toDouble(),
      value: json['value'],
    );
  }
}

@immutable
class BoneAnimation {
  const BoneAnimation({
    required this.boneId,
    this.translationKeyframes = const <Keyframe>[],
    this.rotationKeyframes = const <Keyframe>[],
  });

  final String boneId;
  final List<Keyframe> translationKeyframes;
  final List<Keyframe> rotationKeyframes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'boneId': boneId,
      'translationKeyframes': translationKeyframes
          .map((e) => e.toJson())
          .toList(growable: false),
      'rotationKeyframes': rotationKeyframes
          .map((e) => e.toJson())
          .toList(growable: false),
    };
  }

  factory BoneAnimation.fromJson(Map<String, dynamic> json) {
    return BoneAnimation(
      boneId: json['boneId'] as String,
      translationKeyframes:
          ((json['translationKeyframes'] as List<dynamic>?) ??
                  const <dynamic>[])
              .map((item) => Keyframe.fromJson(item as Map<String, dynamic>))
              .toList(growable: false),
      rotationKeyframes:
          ((json['rotationKeyframes'] as List<dynamic>?) ?? const <dynamic>[])
              .map((item) => Keyframe.fromJson(item as Map<String, dynamic>))
              .toList(growable: false),
    );
  }
}

@immutable
class AnimationClip {
  const AnimationClip({
    required this.name,
    required this.duration,
    this.boneAnimations = const <BoneAnimation>[],
  });

  final String name;
  final double duration;
  final List<BoneAnimation> boneAnimations;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'duration': duration,
      'boneAnimations': boneAnimations
          .map((e) => e.toJson())
          .toList(growable: false),
    };
  }

  factory AnimationClip.fromJson(Map<String, dynamic> json) {
    return AnimationClip(
      name: json['name'] as String,
      duration: (json['duration'] as num).toDouble(),
      boneAnimations:
          ((json['boneAnimations'] as List<dynamic>?) ?? const <dynamic>[])
              .map(
                (item) => BoneAnimation.fromJson(item as Map<String, dynamic>),
              )
              .toList(growable: false),
    );
  }
}

@immutable
class SkeletonProject {
  const SkeletonProject({
    this.bones = const <Bone>[],
    this.animationClips = const <AnimationClip>[],
  });

  final List<Bone> bones;
  final List<AnimationClip> animationClips;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'bones': bones.map((e) => e.toJson()).toList(growable: false),
      'animationClips': animationClips
          .map((e) => e.toJson())
          .toList(growable: false),
    };
  }

  factory SkeletonProject.fromJson(Map<String, dynamic> json) {
    return SkeletonProject(
      bones: ((json['bones'] as List<dynamic>?) ?? const <dynamic>[])
          .map((item) => Bone.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      animationClips:
          ((json['animationClips'] as List<dynamic>?) ?? const <dynamic>[])
              .map(
                (item) => AnimationClip.fromJson(item as Map<String, dynamic>),
              )
              .toList(growable: false),
    );
  }

  AnimationClip? findClipByName(String clipName) {
    for (final clip in animationClips) {
      if (clip.name == clipName) {
        return clip;
      }
    }
    return null;
  }
}
