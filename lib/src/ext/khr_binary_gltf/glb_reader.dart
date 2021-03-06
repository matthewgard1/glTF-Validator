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

library gltf.extensions.khr_binary_gltf.glb;

import "dart:async";
import "dart:convert";
import "dart:math";
import "dart:typed_data";

import 'khr_binary_gltf.dart';
import 'errors.dart';

import 'package:gltf/gltf.dart';
import "package:gltf/src/base/gltf_property.dart";

const int GLTF_ASCII = 0x676C5446;
const int GLB_VERSION = 1;
const int GLB_SCENEFORMAT = 0;

class GlbReader implements GltfReader {
  final bool stopOnBody;
  Future<Gltf> get root => _rootCompleter.future;
  Future<Object> get body => _bodyCompleter.future;

  final Uint8List _header = new Uint8List(20);
  ByteData _headerByteData;

  final _rootCompleter = new Completer<Gltf>();
  final _bodyCompleter = new Completer();
  StreamSubscription<List<int>> _subscription;

  int _sceneSize;
  ByteConversionSink _sceneSink;

  int _bodySize = 0;
  Uint8List _body;

  Context context;

  GlbReader(Stream<List<int>> stream,
      [Context context, this.stopOnBody = false]) {
    this.context = context ?? new Context();
    final outSink =
        new ChunkedConversionSink<Map<String, Object>>.withCallback((json) {
      try {
        this.context.addExtensionOptions(
            new KhrBinaryGltfExtensionOptions(bufferByteLength: _bodySize));
        _rootCompleter.complete(new Gltf.fromMap(json[0], this.context));
      } catch (e, st) {
        _rootCompleter.completeError(e, st);
      }
    });

    _sceneSink = JSON.decoder.startChunkedConversion(outSink).asUtf8Sink(false);

    _headerByteData = new ByteData.view(_header.buffer);
    _subscription = stream.listen(_onData, onError: _onError, onDone: _onDone);
  }

  // States
  static const int START = 0;
  static const int SCENE = 1;
  static const int BODY = 2;

  int _state = START;
  int _bufferIndex = 0;
  int _availableDataLength = 0;

  void _onData(List<int> data) {
    _subscription.pause();
    int index = 0;

    while (index != data.length) {
      switch (_state) {
        case START:
          _availableDataLength =
              min(data.length - index, _header.length - _bufferIndex);
          _header.setRange(
              _bufferIndex, _bufferIndex += _availableDataLength, data, index);
          index += _availableDataLength;

          if (_bufferIndex == _header.length) {
            // Check glTF bytes
            final magic = _headerByteData.getUint32(0);
            if (magic != GLTF_ASCII) {
              context.addIssue(GlbError.INVALID_MAGIC, args: [magic]);
              _onError(context);
              return;
            }

            // Check glTF version
            final version =
                _headerByteData.getUint32(4, Endianness.LITTLE_ENDIAN);
            if (version != GLB_VERSION) {
              context.addIssue(GlbError.INVALID_VERSION, args: [version]);
              _onError(context);
              return;
            }

            // Check glTF scene format
            final sceneFormat = _headerByteData.getUint32(16);
            if (sceneFormat != GLB_SCENEFORMAT) {
              context
                  .addIssue(GlbError.INVALID_SCENEFORMAT, args: [sceneFormat]);
              _onError(context);
              return;
            }

            // Get scene size
            _sceneSize =
                _headerByteData.getUint32(12, Endianness.LITTLE_ENDIAN);

            if (_sceneSize % 4 != 0)
              context.addIssue(GlbWarning.SUB_OPTIMAL_SCENELENGTH,
                  args: [_sceneSize]);

            // Get body size
            final fileLength =
                _headerByteData.getUint32(8, Endianness.LITTLE_ENDIAN);
            _bodySize = fileLength - _header.length - _sceneSize;

            if (_bodySize < 0) {
              context.addIssue(GlbError.FILE_TOO_SHORT);
              _onError(context);
              return;
            }

            if (!stopOnBody) _body = new Uint8List(_bodySize);

            _state = SCENE;
            _bufferIndex = 0;
          }
          break;

        case SCENE:
          _availableDataLength =
              min(data.length - index, _sceneSize - _bufferIndex);
          try {
            _sceneSink.addSlice(
                data, index, index + _availableDataLength, false);
            index += _availableDataLength;
          } catch (e) {
            context.addIssue(GltfError.INVALID_JSON, args: [e]);
            _onError(context);
            return;
          }
          _bufferIndex += _availableDataLength;

          if (_bufferIndex == _sceneSize) {
            try {
              _sceneSink.close();
            } catch (e) {
              context.addIssue(GltfError.INVALID_JSON, args: [e]);
              _onError(context);
              return;
            }

            if (stopOnBody) {
              _subscription.cancel();
              _bodyCompleter.complete(null);
              return;
            }

            _state = BODY;
            _bufferIndex = 0;
          }
          break;

        case BODY:
          _availableDataLength =
              min(data.length - index, _bodySize - _bufferIndex);
          _body.setRange(
              _bufferIndex, _bufferIndex += _availableDataLength, data, index);
          index += _availableDataLength;

          if (_bufferIndex == _bodySize) {
            _subscription.cancel();
            _bodyCompleter.complete(_body);
          }
          break;
      }
    }
    _subscription.resume();
  }

  void _onError(Object error) {
    _subscription.cancel();
    if (!_rootCompleter.isCompleted) _rootCompleter.completeError(error);
  }

  void _onDone() {
    switch (_state) {
      case START:
        context.addIssue(GlbError.UNEXPECTED_END_OF_HEADER);
        break;

      case SCENE:
        if (_bufferIndex != _sceneSize)
          context.addIssue(GlbError.UNEXPECTED_END_OF_SCENE);
        break;

      case BODY:
        if (_bufferIndex != _bodySize)
          context.addIssue(GlbError.UNEXPECTED_END_OF_FILE);
        break;
    }
  }
}
