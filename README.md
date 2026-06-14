# Kindling: Open-Source 2D Skeletal Animation System in Flutter & Dart

Kindling é um sistema de animação esquelética 2D profissional para Flutter/Dart, inspirado em ferramentas como Spine e Tiled. Combina um editor visual completo (`kindling_editor`) com um runtime de animação eficiente (`kindling` package).

## 📦 Estrutura do Projeto

```
kindling/
├── lib/                           # Core package
│   └── src/
│       ├── models/                # Data structures
│       │   ├── skeletal_models.dart    # Bone, AnimationClip, Keyframe
│       │   └── sprite_models.dart      # SpriteGroup, SpriteDefinition (novo)
│       ├── components/            # Flame components
│       │   └── skeletal_animation_component.dart  # Runtime playback com blend
│       └── math/
│           └── skeleton_math.dart      # Transform math & interpolation
├── kindling_editor/               # Editor Flutter app
│   └── lib/
│       ├── main.dart                  # Bootstrap + editor shell
│       └── editor_support.dart        # Painters, dialog and UI helpers
├── example/                        # Preview app
│   └── lib/main.dart                  # Importa JSON e visualiza com blend
└── pubspec.yaml
```

## ✅ O Que Já Foi Implementado

### 1. **Core Runtime (`kindling` package)**
- ✅ Modelos imutáveis de dados: `Bone`, `AnimationClip`, `Keyframe`, `SkeletonProject`
- ✅ JSON serialization completo (export/import)
- ✅ Math transforms: matrizes globais, interpolação de rotação
- ✅ `SkeletalAnimationComponent`: Flame component com:
  - Play/stop de clips
  - **Blend transitions** entre animações (smooth interpolation)
  - Render com sprites por osso (via `localScale`)
  - Suporte a hierarquias profundas de ossos

### 2. **Skeleton Editor (`kindling_editor`)**
- ✅ **Hierarchy Panel**: Visualização em árvore de ossos com parent/children display
- ✅ **Canvas Panel**: 
  - Renderização de skeleton com grid de fundo
  - Seleção de ossos com visual feedback
  - **Drag to rotate**: arraste no osso para rotacionar via gizmo
  - Renderização de sprites (se carregados)
- ✅ **Inspector Panel**:
  - Edição de comprimento (length) com slider 10-300px
  - Input manual de rotação em radianos
  - Gestão de sprites PNG (attach/remove)
- ✅ **Timeline Panel** (unificado):
  - Ruler com marcas de tempo (0s, 1s, 2s, etc)
  - Track list por osso com nomes
  - CustomPaint para visual de keyframes (diamantes)
  - **Playhead sincronizado** (linha vermelha)
  - Click-to-scrub para mudar tempo selecionado
  - Input de duração da timeline em segundos (250ms-120s)
- ✅ **Playback Controls**:
  - Botão Play/Pause com AnimationController
  - Display do tempo atual vs duração
  - Animação suave dos bones em tempo real
- ✅ **Exportação JSON**: 
  - Formatted text com copy-to-clipboard
  - Contém bones, clips, keyframes, rotações animadas
- ✅ **Osso Management**:
  - Adicionar filhos ao osso selecionado (mantém pai selecionado, permite múltiplos filhos no root)
  - Posicionamento automático de filhos na ponta do pai
  - Deletar osso e descendentes com proteção (não pode apagar tudo)
- ✅ **Hierarquia Visual**:
  - Labels em árvore com `|--` prefixes
  - Display de parent e counts de children
  - Indentação por profundidade

### 3. **Example Preview App**
- ✅ Importação de JSON via texto
- ✅ Importação opcional de `spritegroups.json`
- ✅ Campo de diretório base para resolver sprites PNG
- ✅ Seleção de clip com botões
- ✅ Slider de blend duration
- ✅ Auto-switch toggle para replay contínuo
- ✅ HUD overlay com controles visíveis

## 🎯 Próximos Passos (Atualizado)

### Fase 1: Sprite Groups Manager - ✅ COMPLETA
**Objetivo**: Sistema de sprite sheets com base64 e partes nomeadas.

**Concluído**:
- ✅ Aba "Sprite Groups" no editor com TabBar
- ✅ Grid de grupos com cards e ações de remoção
- ✅ Importação de imagem com file picker + base64
- ✅ Gerenciamento de parts em dialog
- ✅ Inspector com `spriteGroupId` e `spritePartId`
- ✅ Exportação dual: `skeleton.json` + `spritegroups.json`
- ✅ Preview runtime carrega sprite groups e exibe sprites vinculados ao esqueleto

### Fase 2: Vertex Editor Canvas - em andamento
**Objetivo**: Desenhar e manipular vértices para recortar sprite areas.

**Já disponível**:
- ✅ Preview da imagem do sprite group ao abrir os detalhes
- ✅ Editor de part com canvas para clicar e desenhar vértices por cima da imagem
- ✅ Undo/Clear para refazer o polígono
- ✅ Inspector com `Sprite Offset X/Y` por osso (persistido no JSON)
- ✅ Skeleton canvas renderiza a part selecionada (`spritePartId`) com offset aplicado

**Próximas tarefas**:
1. Canvas para adicionar/mover/remover vértices
2. Validação de polígonos e self-intersections
3. Preview lado a lado da imagem original e do corte

### Fase 3: Sprite Clipping no Runtime
**Objetivo**: Usar vertices para recortar a imagem no preview/runtime.

**Próximas tarefas**:
1. ClipPath/CustomPaint por part
2. Suporte a múltiplas parts por grupo no runtime
3. Exibir fallback quando o part não tiver vértices

### Fase 4: UX Profissional
**Objetivo**: Refinar a experiência do editor e do preview.

**Próximas tarefas**:
1. Undo/Redo
2. Themes e hotkeys
3. Grid snapping
4. Export PNG do preview
5. Cache e melhorias de performance

## 🔨 Como Continuar o Projeto

### Local Setup
```bash
# Install dependencies
flutter pub get
cd kindling_editor && flutter pub get
cd ../example && flutter pub get

# Run tests
cd ../.. && flutter test

# Run editor
cd kindling_editor && flutter run -d linux

# Run example (preview)
cd ../example && flutter run -d linux
```

### Estrutura de Commits Recomendada
1. **`feat: sprite-groups-aba`** → Adicionar 2ª aba com lista de groups
2. **`feat: sprite-import-base64`** → File picker + base64 conversion
3. **`feat: vertex-editor-canvas`** → Canvas com add/drag/remove verts
4. **`feat: runtime-sprite-clipping`** → Usar verts ao renderizar
5. **`feat: spritegroups-export-json`** → Dual JSON export

### Pontos de Atenção
- O `Bone` model já tem `spriteGroupId` + `spritePartId` (compatível backwards)
- O `SpriteGroup` e `SpriteDefinition` models já existem em `lib/src/models/sprite_models.dart`
- Usar `base64Encode`/`base64Decode` de `dart:convert`
- Em `kindling_editor`, considere mixin `TickerProviderStateMixin` para anims de UI
- Evite `ListView` dentro de `ListView` (use `Expanded` + CustomScroll ao invés)

## 📊 Dependências Adicionadas (Para Spray Groups)
```yaml
dependencies:
  file_picker: ^5.4.0  # Import de imagens
  convert: ^3.1.0      # (optional) helpers para base64
  image: ^4.0.0        # (optional) manipulation de imagem em memória
```

## 🎨 Design Patterns Usados
- **Immutable models** com `@immutable` + `copyWith()`
- **JSON serialization** via factory constructors
- **Flame components** para runtime rendering
- **State management** via `setState()` (suficiente para MVP)
- **Observer pattern** com `AnimationController.addListener()`

## 📝 Notas de Arquitetura

### Por que SpriteGroups separado?
1. **Reutilização**: Uma imagem pode ter múltiplas parts, múltiplos ossos podem usar mesma part
2. **Performance**: Carregar imagem 1x, referenciar N vezes
3. **Modularidade**: Fácil swapear spritegroups em runtime

### Por que base64 no JSON?
1. **Portabilidade**: JSON é self-contained, sem paths externos
2. **Cross-platform**: Web também consegue trabalhar
3. **Backup**: Tudo em um arquivo único

### Blending de Animações
- Implementado com `lerp` entre poses
- `_blendingDurationMs` controla suavidade
- Ótimo para transições idle→walk→run

## 🐛 Troubleshooting

### "Cannot load image" ao importar sprite
- Compatível apenas com PNG/JPG no `file_picker`
- Base64 pode ficar >50MB com imagens muito grandes (considere compress)
- Use ferramentas como ImageMagick para reduzir tamanho pre-import

###  "Skeleton is null" no example
- Certifique-se JSON exportado tem estrutura correta
- Teste com `flutter test` na pasta `kindling`

### Timeline scroll lento com muitos bones
- Considere `ListView.separated()` ao invés de `ListView.builder()`
- Verifique `CustomPaint.shouldRepaint()` retorna `false` quando possível

## 📖 Referências
- [Spine Editor](http://esotericsoftware.com/) (inspiração UX)
- [Tiled Map Editor](https://www.mapeditor.org/) (dual JSON pattern)
- [Flutter Flame](https://flame-engine.org/) (rendering)
- [vector_math](https://pub.dev/packages/vector_math) (transforms)

---

**Status**: MVP v1 + Sprite Groups Manager ✅ | Próximo Milestone: Vertex Editor Canvas  
**Linguagem**: Dart 3.11+  
**Framework**: Flutter 3.16+  
**License**: (Adicionar conforme necessário)
