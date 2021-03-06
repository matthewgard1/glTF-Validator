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

library gltf.gltf_reader;

import "dart:async";
import "dart:convert";

import "package:gltf/src/context.dart";
import "package:gltf/src/base/gltf.dart";
import 'package:gltf/src/errors.dart';

export "package:gltf/src/context.dart";
export "package:gltf/src/base/gltf.dart";

abstract class GltfReader {
  Future<Gltf> get root;
  Context context;

  factory GltfReader(Stream<List<int>> stream, [Context context]) =>
      new GltfJsonReader(stream, context);
}

class GltfJsonReader implements GltfReader {
  Future<Gltf> get root => _rootCompleter.future;

  final _rootCompleter = new Completer<Gltf>();
  StreamSubscription<List<int>> _subscription;

  ByteConversionSink _byteSink;

  Context context;

  GltfJsonReader(Stream<List<int>> stream, [Context context]) {
    this.context = context ?? new Context();
    final outSink =
        new ChunkedConversionSink<Map<String, Object>>.withCallback((json) {
      try {
        _rootCompleter.complete(new Gltf.fromMap(json[0], this.context));
      } catch (e, st) {
        _rootCompleter.completeError(e, st);
      }
    });

    _byteSink = JSON.decoder.startChunkedConversion(outSink).asUtf8Sink(false);
    _subscription = stream.listen(_onData, onError: _onError, onDone: _onDone);
  }

  void _onData(List<int> data) {
    _subscription.pause();
    try {
      _byteSink.addSlice(data, 0, data.length, false);
      _subscription.resume();
    } on FormatException catch (e) {
      context.addIssue(GltfError.INVALID_JSON, args: [e]);
      _onError(context);
    }
  }

  void _onError(Object error) {
    _subscription.cancel();
    if (!_rootCompleter.isCompleted) _rootCompleter.completeError(error);
  }

  void _onDone() {
    try {
      _byteSink.close();
    } on FormatException catch (e) {
      context.addIssue(GltfError.INVALID_JSON, args: [e]);
      _onError(context);
    }
  }
}
