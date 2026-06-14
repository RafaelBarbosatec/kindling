import 'dart:ui';

import 'package:vector_math/vector_math.dart';

import '../models/skeletal_models.dart';

class BonePose {
  const BonePose({
    required this.localPosition,
    required this.localRotation,
    required this.localScale,
  });

  final Offset localPosition;
  final double localRotation;
  final double localScale;

  factory BonePose.fromBone(Bone bone) {
    return BonePose(
      localPosition: bone.localPosition,
      localRotation: bone.localRotation,
      localScale: bone.localScale,
    );
  }
}

class SkeletonMath {
  static Matrix4 buildLocalTransform(BonePose pose) {
    return Matrix4.identity()
      ..translateByDouble(
        pose.localPosition.dx,
        pose.localPosition.dy,
        0.0,
        1.0,
      )
      ..rotateZ(pose.localRotation)
      ..scaleByDouble(pose.localScale, pose.localScale, 1.0, 1.0);
  }

  static Map<String, Matrix4> computeGlobalTransforms({
    required List<Bone> bones,
    Map<String, BonePose> overrides = const <String, BonePose>{},
  }) {
    final byId = <String, Bone>{for (final bone in bones) bone.id: bone};

    final childrenByParent = <String?, List<Bone>>{};
    for (final bone in bones) {
      childrenByParent.putIfAbsent(bone.parentId, () => <Bone>[]).add(bone);
    }

    final global = <String, Matrix4>{};

    void visit(Bone bone, Matrix4 parentTransform) {
      final pose = overrides[bone.id] ?? BonePose.fromBone(bone);
      final localTransform = buildLocalTransform(pose);
      final worldTransform = parentTransform.multiplied(localTransform);
      global[bone.id] = worldTransform;

      for (final child in (childrenByParent[bone.id] ?? const <Bone>[])) {
        visit(child, worldTransform);
      }
    }

    final roots = childrenByParent[null] ?? const <Bone>[];
    for (final root in roots) {
      visit(root, Matrix4.identity());
    }

    for (final bone in bones) {
      if (!global.containsKey(bone.id)) {
        final parent = byId[bone.parentId];
        if (parent == null) {
          visit(bone, Matrix4.identity());
        }
      }
    }

    return global;
  }
}
