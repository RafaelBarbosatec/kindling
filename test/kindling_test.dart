import 'package:flutter_test/flutter_test.dart';
import 'package:kindling/kindling.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  test('serializes and deserializes skeleton project', () {
    const project = SkeletonProject(
      bones: <Bone>[
        Bone(
          id: 'root',
          name: 'Root',
          spritePath: 'sprites/root.png',
          localPosition: Offset.zero,
          localRotation: 0,
          localScale: 1,
        ),
      ],
      animationClips: <AnimationClip>[
        AnimationClip(
          name: 'idle',
          duration: 1000,
          boneAnimations: <BoneAnimation>[
            BoneAnimation(
              boneId: 'root',
              rotationKeyframes: <Keyframe>[
                Keyframe(time: 0, value: 0.0),
                Keyframe(time: 500, value: 1.0),
              ],
            ),
          ],
        ),
      ],
    );

    final decoded = SkeletonProject.fromJson(project.toJson());

    expect(decoded.bones.length, 1);
    expect(decoded.bones.first.spritePath, 'sprites/root.png');
    expect(decoded.animationClips.length, 1);
    expect(decoded.animationClips.first.boneAnimations.first.boneId, 'root');
  });

  test('computes global transform with parent accumulation', () {
    const bones = <Bone>[
      Bone(
        id: 'root',
        name: 'Root',
        localPosition: Offset(10, 0),
        localRotation: 0,
        localScale: 1,
      ),
      Bone(
        id: 'arm',
        name: 'Arm',
        parentId: 'root',
        localPosition: Offset(5, 0),
        localRotation: 0,
        localScale: 1,
      ),
    ];

    final transforms = SkeletonMath.computeGlobalTransforms(bones: bones);
    final arm = transforms['arm']!;
    final translated = arm.transform3(Vector3.zero());

    expect(translated.x, closeTo(15, 0.0001));
    expect(translated.y, closeTo(0, 0.0001));
  });

  test('linearly interpolates rotation', () {
    final value = SkeletalAnimationComponent.interpolateRotationLinear(
      from: 0,
      to: 1,
      t: 0.5,
    );

    expect(value, closeTo(0.5, 0.0001));
  });
}
