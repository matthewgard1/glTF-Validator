/*
 * # Copyright (c) 2016 The Khronos Group Inc.
 * # Copyright (c) 2016 Alexey Knyazev
 * #
 * # Licensed under the Apache License, Version 2.0 (the "License");
 * # you may not use this file except in compliance with the License.
 * # You may obtain a copy of the License at
 * #
 * #     http://www.apache.org/licenses/LICENSE-2.0
 * #
 * # Unless required by applicable law or agreed to in writing, software
 * # distributed under the License is distributed on an "AS IS" BASIS,
 * # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * # See the License for the specific language governing permissions and
 * # limitations under the License.
 */

library gltf.core.gltf;

import 'package:gltf/src/gl.dart' as gl;

import 'accessor.dart';
import 'animation.dart';
import 'asset.dart';
import 'buffer.dart';
import 'buffer_view.dart';
import 'camera.dart';
import 'gltf_property.dart';
import 'image.dart';
import 'material.dart';
import 'mesh.dart';
import 'node.dart';
import 'program.dart';
import 'sampler.dart';
import 'scene.dart';
import 'shader.dart';
import 'skin.dart';
import 'technique.dart';
import 'texture.dart';

export 'accessor.dart';
export 'animation.dart';
export 'asset.dart';
export 'buffer.dart';
export 'buffer_view.dart';
export 'camera.dart';
export 'image.dart';
export 'material.dart';
export 'mesh.dart';
export 'node.dart';
export 'program.dart';
export 'sampler.dart';
export 'scene.dart';
export 'shader.dart';
export 'skin.dart';
export 'technique.dart';
export 'texture.dart';

class Gltf extends GltfProperty {
  final List<String> extensionsUsed;
  final List<String> glExtensionsUsed;
  final Map<String, Accessor> accessors;
  final Map<String, Animation> animations;
  final Asset asset;
  final Map<String, Buffer> buffers;
  final Map<String, BufferView> bufferViews;
  final Map<String, Camera> cameras;
  final Map<String, Image> images;
  final Map<String, Material> materials;
  final Map<String, Mesh> meshes;
  final Map<String, Node> nodes;
  final Map<String, Program> programs;
  final Map<String, Sampler> samplers;
  final String sceneId;
  final Scene scene;
  final Map<String, Scene> scenes;
  final Map<String, Shader> shaders;
  final Map<String, Skin> skins;
  final Map<String, Technique> techniques;
  final Map<String, Texture> textures;

  final Map<String, Node> joints = <String, Node>{};

  Gltf._(
      this.extensionsUsed,
      this.glExtensionsUsed,
      this.accessors,
      this.animations,
      this.asset,
      this.buffers,
      this.bufferViews,
      this.cameras,
      this.images,
      this.materials,
      this.meshes,
      this.nodes,
      this.programs,
      this.samplers,
      this.sceneId,
      this.scene,
      this.scenes,
      this.shaders,
      this.skins,
      this.techniques,
      this.textures,
      Map<String, Object> extensions,
      Object extras)
      : super(extensions, extras);

  factory Gltf.fromMap(Map<String, Object> map, Context context) {
    context.path
      ..clear()
      ..add(GLTF);
    if (context.validate) checkMembers(map, GLTF_MEMBERS, context);

    // Prepare glTF extensions handlers
    final extensionsUsed =
        getStringList(map, EXTENSIONS_USED, context, def: <String>[]);
    context.initExtensions(extensionsUsed ?? <String>[]);

    // TODO: check for repeating items

    // Get used GL extensions and store valid in the current `context`.
    const glExtensionsUsedEnum = const <String>[gl.OES_ELEMENT_INDEX_UINT];

    final glExtensionsUsed = getStringList(map, GL_EXTENSIONS_USED, context,
        list: glExtensionsUsedEnum, def: <String>[]);

    context.initGlExtensions(glExtensionsUsed ?? <String>[]);

    // Helper function for converting JSON dictionary to Map of proper glTF objects
    Map<String, Object> toMap(String name, FromMapFunction fromMap,
        {bool req: false}) {
      final items = getMap(map, name, context, req: req);
      context.path
        ..clear()
        ..add(name);

      for (final id in items.keys) {
        final itemMap = getMap(items, id, context, req: true);
        if (itemMap.isEmpty) continue;
        context.path.add(id);
        items[id] = fromMap(itemMap, context);
        context.path.removeLast();
      }

      return items;
    }

    // Helper function for converting JSON dictionary to proper glTF object
    Object toValue(String name, FromMapFunction fromMap, {bool req: false}) {
      final item = getMap(map, name, context, req: req);
      context.path
        ..clear()
        ..add(name);
      if (item == null) return null;
      return fromMap(item, context);
    }

    final Asset asset = toValue(ASSET, Asset.fromMap, req: true);

    final Map<String, Accessor> accessors =
        toMap(ACCESSORS, Accessor.fromMap, req: true);

    final Map<String, Animation> animations =
        toMap(ANIMATIONS, Animation.fromMap);

    final Map<String, Buffer> buffers =
        toMap(BUFFERS, Buffer.fromMap, req: true);

    final Map<String, BufferView> bufferViews =
        toMap(BUFFER_VIEWS, BufferView.fromMap, req: true);

    final Map<String, Camera> cameras = toMap(CAMERAS, Camera.fromMap);

    final Map<String, Image> images = toMap(IMAGES, Image.fromMap);

    final Map<String, Material> materials = toMap(MATERIALS, Material.fromMap);

    final Map<String, Mesh> meshes = toMap(MESHES, Mesh.fromMap, req: true);

    final Map<String, Node> nodes = toMap(NODES, Node.fromMap);

    final Map<String, Program> programs = toMap(PROGRAMS, Program.fromMap);

    final Map<String, Sampler> samplers = toMap(SAMPLERS, Sampler.fromMap);

    final Map<String, Scene> scenes = toMap(SCENES, Scene.fromMap);

    final sceneId = getId(map, SCENE, context, req: false);

    final scene = scenes[sceneId];

    if (context.validate && sceneId != null && scene == null)
      context.addIssue(GltfError.UNRESOLVED_REFERENCE,
          name: SCENE, args: [sceneId]);

    final Map<String, Shader> shaders = toMap(SHADERS, Shader.fromMap);

    final Map<String, Skin> skins = toMap(SKINS, Skin.fromMap);

    final Map<String, Technique> techniques =
        toMap(TECHNIQUES, Technique.fromMap);

    final Map<String, Texture> textures = toMap(TEXTURES, Texture.fromMap);

    context.path
      ..clear()
      ..add(GLTF);

    final gltf = new Gltf._(
        extensionsUsed,
        glExtensionsUsed,
        accessors,
        animations,
        asset,
        buffers,
        bufferViews,
        cameras,
        images,
        materials,
        meshes,
        nodes,
        programs,
        samplers,
        sceneId,
        scene,
        scenes,
        shaders,
        skins,
        techniques,
        textures,
        getExtensions(map, Gltf, context),
        getExtras(map));

    // Step 2: linking IDs
    context.path.clear();

    final topLevelMaps = <String, Map<String, GltfProperty>>{
      ACCESSORS: accessors,
      ANIMATIONS: animations,
      BUFFER_VIEWS: bufferViews,
      MATERIALS: materials,
      PROGRAMS: programs,
      SCENES: scenes,
      TECHNIQUES: techniques,
      TEXTURES: textures
    };

    void linkCollection(String key, Map<String, GltfProperty> collection) {
      context.path.add(key);
      collection.forEach((id, item) {
        context.path.add(id);
        if (item is Linkable)
          (item as dynamic/*=Linkable*/).link(gltf, context);
        if (item.extensions.isNotEmpty) {
          context.path.add(EXTENSIONS);
          item.extensions.forEach((name, extension) {
            context.path.add(name);
            if (extension is Linkable) extension.link(gltf, context);
            context.path.removeLast();
          });
          context.path.removeLast();
        }
        context.path.removeLast();
      });
      context.path.removeLast();
    }

    topLevelMaps.forEach(linkCollection);

    // Fixed order
    linkCollection(NODES, nodes);
    linkCollection(SKINS, skins);
    linkCollection(MESHES, meshes);

    return gltf;
  }
}
