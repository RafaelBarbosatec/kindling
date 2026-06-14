import 'dart:ui';

import 'package:flutter/foundation.dart';

@immutable
class SpriteDefinition {
  const SpriteDefinition({
    required this.id,
    required this.vertices,
  });

  final String id;
  final List<Offset> vertices;

  SpriteDefinition copyWith({
    String? id,
    List<Offset>? vertices,
  }) {
    return SpriteDefinition(
      id: id ?? this.id,
      vertices: vertices ?? this.vertices,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'vertices': vertices
          .map((v) => <String, double>{'x': v.dx, 'y': v.dy})
          .toList(),
    };
  }

  factory SpriteDefinition.fromJson(Map<String, dynamic> json) {
    final verticesList = (json['vertices'] as List?)?.cast<Map<String, dynamic>?>()
        .whereType<Map<String, dynamic>>()
        .map((v) => Offset(
          (v['x'] as num).toDouble(),
          (v['y'] as num).toDouble(),
        ))
        .toList() ?? const <Offset>[];

    return SpriteDefinition(
      id: json['id'] as String,
      vertices: verticesList,
    );
  }
}

@immutable
class SpriteGroup {
  const SpriteGroup({
    required this.id,
    required this.imageBase64,
    required this.sprites,
  });

  final String id;
  final String imageBase64;
  final List<SpriteDefinition> sprites;

  SpriteGroup copyWith({
    String? id,
    String? imageBase64,
    List<SpriteDefinition>? sprites,
  }) {
    return SpriteGroup(
      id: id ?? this.id,
      imageBase64: imageBase64 ?? this.imageBase64,
      sprites: sprites ?? this.sprites,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'imageBase64': imageBase64,
      'sprites': sprites.map((s) => s.toJson()).toList(),
    };
  }

  factory SpriteGroup.fromJson(Map<String, dynamic> json) {
    final spritesList = (json['sprites'] as List?)
        ?.map((s) => SpriteDefinition.fromJson(s as Map<String, dynamic>))
        .toList() ?? const <SpriteDefinition>[];

    return SpriteGroup(
      id: json['id'] as String,
      imageBase64: json['imageBase64'] as String,
      sprites: spritesList,
    );
  }
}
