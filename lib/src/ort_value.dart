import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:onnxruntime/src/bindings/onnxruntime_bindings_generated.dart'
    as bindings;
import 'package:onnxruntime/src/ort_env.dart';
import 'package:onnxruntime/src/ort_status.dart';
import 'package:onnxruntime/src/util/list_shape_extension.dart';

abstract class OrtValue {
  late ffi.Pointer<bindings.OrtValue> _ptr;

  ffi.Pointer<bindings.OrtValue> get ptr => _ptr;

  int get address => _ptr.address;

  Object? get value;

  Map<OrtTensorTypeAndShapeInfo, OrtTensorTypeAndShapeInfo> _createMapInfo(
      ffi.Pointer<bindings.OrtValue> ortValuePtr) {
    final keyPtrPtr = calloc<ffi.Pointer<bindings.OrtValue>>();
    final keyPtr = _getOrtValue(ortValuePtr, 0, keyPtrPtr);
    final keyInfo = OrtTensorTypeAndShapeInfo(keyPtr);
    _releaseOrtValue(keyPtr);
    calloc.free(keyPtrPtr);

    final valuePtrPtr = calloc<ffi.Pointer<bindings.OrtValue>>();
    final valuePtr = _getOrtValue(ortValuePtr, 1, valuePtrPtr);
    final valueInfo = OrtTensorTypeAndShapeInfo(valuePtr);
    _releaseOrtValue(valuePtr);
    calloc.free(valuePtrPtr);
    return {keyInfo: valueInfo};
  }

  ffi.Pointer<bindings.OrtValue> _getOrtValue(
      ffi.Pointer<bindings.OrtValue> ortValuePtr,
      int index,
      ffi.Pointer<ffi.Pointer<bindings.OrtValue>> indexOrtValuePtrPtr) {
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.GetValue.asFunction<
            bindings.OrtStatusPtr Function(
                ffi.Pointer<bindings.OrtValue>,
                int,
                ffi.Pointer<bindings.OrtAllocator>,
                ffi.Pointer<ffi.Pointer<bindings.OrtValue>>)>()(
        ortValuePtr, index, OrtAllocator.instance.ptr, indexOrtValuePtrPtr);
    OrtStatus.checkOrtStatus(statusPtr);
    return indexOrtValuePtrPtr.value;
  }

  ffi.Pointer<T> _getTensorMutableData<T extends ffi.NativeType>(
      ffi.Pointer<bindings.OrtValue> ortValuePtr,
      ffi.Pointer<ffi.Pointer<T>> dataPtrPtr) {
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.GetTensorMutableData
            .asFunction<
                bindings.OrtStatusPtr Function(ffi.Pointer<bindings.OrtValue>,
                    ffi.Pointer<ffi.Pointer<ffi.Void>>)>()(
        ortValuePtr, dataPtrPtr.cast());
    OrtStatus.checkOrtStatus(statusPtr);
    return dataPtrPtr.value;
  }

  List<String> _getStringList(ffi.Pointer<bindings.OrtValue> ortValuePtr) {
    final info = OrtTensorTypeAndShapeInfo(ortValuePtr);
    final tensorShapeElementCount = info._tensorShapeElementCount;
    final dataLengthPtr = calloc<ffi.Size>();
    var statusPtr = OrtEnv.instance.ortApiPtr.ref.GetStringTensorDataLength
        .asFunction<
            bindings.OrtStatusPtr Function(ffi.Pointer<bindings.OrtValue>,
                ffi.Pointer<ffi.Size>)>()(ortValuePtr, dataLengthPtr);
    OrtStatus.checkOrtStatus(statusPtr);
    final dataLength = dataLengthPtr.value;
    calloc.free(dataLengthPtr);
    // last index is '\0'
    final dataPtr = calloc<ffi.Char>(dataLength + 1);
    // last index is dataLength
    final offsetPtr = calloc<ffi.Size>(tensorShapeElementCount + 1);
    statusPtr = OrtEnv.instance.ortApiPtr.ref.GetStringTensorContent.asFunction<
            bindings.OrtStatusPtr Function(ffi.Pointer<bindings.OrtValue>,
                ffi.Pointer<ffi.Void>, int, ffi.Pointer<ffi.Size>, int)>()(
        ortValuePtr,
        dataPtr.cast(),
        dataLength,
        offsetPtr,
        tensorShapeElementCount);
    OrtStatus.checkOrtStatus(statusPtr);
    statusPtr = OrtEnv.instance.ortApiPtr.ref.GetStringTensorDataLength
            .asFunction<
                bindings.OrtStatusPtr Function(
                    ffi.Pointer<bindings.OrtValue>, ffi.Pointer<ffi.Size>)>()(
        ortValuePtr,
        ffi.Pointer.fromAddress(offsetPtr.address +
            tensorShapeElementCount * ffi.sizeOf<ffi.Size>()));
    OrtStatus.checkOrtStatus(statusPtr);
    final list = <String>[];
    for (int i = 0; i < tensorShapeElementCount; ++i) {
      final size = offsetPtr[i + 1] - offsetPtr[i];
      final strPtr = calloc<ffi.Char>(size + 1);
      for (int j = 0; j < size; ++j) {
        strPtr[j] = dataPtr[offsetPtr[i] + j];
      }
      final str = strPtr.cast<Utf8>().toDartString();
      list.add(str);
      calloc.free(strPtr);
    }
    calloc.free(dataPtr);
    calloc.free(offsetPtr);
    return list;
  }

  List<num> _getNumList(ffi.Pointer<bindings.OrtValue> ortValuePtr) {
    final info = OrtTensorTypeAndShapeInfo(ortValuePtr);
    final tensorElementType = info._tensorElementType;
    final tensorShapeElementCount = info._tensorShapeElementCount;
    final data = <num>[];
    if (tensorElementType == ONNXTensorElementDataType.uint8) {
      final dataPtrPtr = calloc<ffi.Pointer<ffi.Uint8>>();
      final dataPtr = _getTensorMutableData(ortValuePtr, dataPtrPtr);
      for (int i = 0; i < tensorShapeElementCount; ++i) {
        data.add(dataPtr[i]);
      }
      calloc.free(dataPtrPtr);
    } else if (tensorElementType == ONNXTensorElementDataType.int8) {
      final dataPtrPtr = calloc<ffi.Pointer<ffi.Int8>>();
      final dataPtr = _getTensorMutableData(ortValuePtr, dataPtrPtr);
      for (int i = 0; i < tensorShapeElementCount; ++i) {
        data.add(dataPtr[i]);
      }
      calloc.free(dataPtrPtr);
    } else if (tensorElementType == ONNXTensorElementDataType.uint16) {
      final dataPtrPtr = calloc<ffi.Pointer<ffi.Uint16>>();
      final dataPtr = _getTensorMutableData(ortValuePtr, dataPtrPtr);
      for (int i = 0; i < tensorShapeElementCount; ++i) {
        data.add(dataPtr[i]);
      }
      calloc.free(dataPtrPtr);
    } else if (tensorElementType == ONNXTensorElementDataType.int16) {
      final dataPtrPtr = calloc<ffi.Pointer<ffi.Int16>>();
      final dataPtr = _getTensorMutableData(ortValuePtr, dataPtrPtr);
      for (int i = 0; i < tensorShapeElementCount; ++i) {
        data.add(dataPtr[i]);
      }
      calloc.free(dataPtrPtr);
    } else if (tensorElementType == ONNXTensorElementDataType.uint32) {
      final dataPtrPtr = calloc<ffi.Pointer<ffi.Uint32>>();
      final dataPtr = _getTensorMutableData(ortValuePtr, dataPtrPtr);
      for (int i = 0; i < tensorShapeElementCount; ++i) {
        data.add(dataPtr[i]);
      }
      calloc.free(dataPtrPtr);
    } else if (tensorElementType == ONNXTensorElementDataType.int32) {
      final dataPtrPtr = calloc<ffi.Pointer<ffi.Int32>>();
      final dataPtr = _getTensorMutableData(ortValuePtr, dataPtrPtr);
      for (int i = 0; i < tensorShapeElementCount; ++i) {
        data.add(dataPtr[i]);
      }
      calloc.free(dataPtrPtr);
    } else if (tensorElementType == ONNXTensorElementDataType.uint64) {
      final dataPtrPtr = calloc<ffi.Pointer<ffi.Uint64>>();
      final dataPtr = _getTensorMutableData(ortValuePtr, dataPtrPtr);
      for (int i = 0; i < tensorShapeElementCount; ++i) {
        data.add(dataPtr[i]);
      }
      calloc.free(dataPtrPtr);
    } else if (tensorElementType == ONNXTensorElementDataType.int64) {
      final dataPtrPtr = calloc<ffi.Pointer<ffi.Int64>>();
      final dataPtr = _getTensorMutableData(ortValuePtr, dataPtrPtr);
      for (int i = 0; i < tensorShapeElementCount; ++i) {
        data.add(dataPtr[i]);
      }
      calloc.free(dataPtrPtr);
    } else if (tensorElementType == ONNXTensorElementDataType.float) {
      final dataPtrPtr = calloc<ffi.Pointer<ffi.Float>>();
      final dataPtr = _getTensorMutableData(ortValuePtr, dataPtrPtr);
      for (int i = 0; i < tensorShapeElementCount; ++i) {
        data.add(dataPtr[i]);
      }
      calloc.free(dataPtrPtr);
    } else if (tensorElementType == ONNXTensorElementDataType.double) {
      final dataPtrPtr = calloc<ffi.Pointer<ffi.Double>>();
      final dataPtr = _getTensorMutableData(ortValuePtr, dataPtrPtr);
      for (int i = 0; i < tensorShapeElementCount; ++i) {
        data.add(dataPtr[i]);
      }
      calloc.free(dataPtrPtr);
    }
    return data;
  }

  List<bool> _getBoolList(ffi.Pointer<bindings.OrtValue> ortValuePtr) {
    final info = OrtTensorTypeAndShapeInfo(ortValuePtr);
    final tensorElementType = info._tensorElementType;
    final tensorShapeElementCount = info._tensorShapeElementCount;
    final data = <bool>[];
    if (tensorElementType == ONNXTensorElementDataType.bool) {
      final dataPtrPtr = calloc<ffi.Pointer<ffi.Bool>>();
      final dataPtr = _getTensorMutableData(ortValuePtr, dataPtrPtr);
      for (int i = 0; i < tensorShapeElementCount; ++i) {
        data.add(dataPtr[i]);
      }
      calloc.free(dataPtrPtr);
    }
    return data;
  }

  _releaseOrtValue(ffi.Pointer<bindings.OrtValue> ortValuePtr) {
    OrtEnv.instance.ortApiPtr.ref.ReleaseValue
            .asFunction<void Function(ffi.Pointer<bindings.OrtValue>)>()(
        ortValuePtr);
  }

  release() {
    _releaseOrtValue(_ptr);
  }
}

class OrtValueTensor extends OrtValue {
  late OrtTensorTypeAndShapeInfo _info;

  OrtValueTensor(ffi.Pointer<bindings.OrtValue> ptr) {
    _ptr = ptr;
    _info = OrtTensorTypeAndShapeInfo(ptr);
  }

  factory OrtValueTensor.fromAddress(int address) {
    return OrtValueTensor(ffi.Pointer.fromAddress(address));
  }

  static OrtValueTensor _createTensorWithString(String data) {
    return _createTensorWithStringList(<String>[data], []);
  }

  static OrtValueTensor _createTensorWithStringList(List<String> data,
      [List<int>? shape]) {
    final ortValuePtrPtr = calloc<ffi.Pointer<bindings.OrtValue>>();
    shape ??= data.shape;
    final shapeSize = shape.length;
    final shapePtr = calloc<ffi.Int64>(shapeSize);
    shapePtr.asTypedList(shapeSize).setRange(0, shapeSize, shape);

    var statusPtr = OrtEnv.instance.ortApiPtr.ref.CreateTensorAsOrtValue
            .asFunction<
                bindings.OrtStatusPtr Function(
                    ffi.Pointer<bindings.OrtAllocator>,
                    ffi.Pointer<ffi.Int64> shape,
                    int,
                    int,
                    ffi.Pointer<ffi.Pointer<bindings.OrtValue>>)>()(
        OrtAllocator.instance.ptr,
        shapePtr,
        shapeSize,
        ONNXTensorElementDataType.string.value,
        ortValuePtrPtr);
    OrtStatus.checkOrtStatus(statusPtr);
    final ortValuePtr = ortValuePtrPtr.value;
    for (int i = 0; i < data.length; ++i) {
      final str = data[i].toNativeUtf8().cast<ffi.Char>();
      statusPtr = OrtEnv.instance.ortApiPtr.ref.FillStringTensorElement
          .asFunction<
              bindings.OrtStatusPtr Function(ffi.Pointer<bindings.OrtValue>,
                  ffi.Pointer<ffi.Char>, int)>()(ortValuePtr, str, i);
      OrtStatus.checkOrtStatus(statusPtr);
    }
    calloc.free(ortValuePtrPtr);
    calloc.free(shapePtr);
    return OrtValueTensor(ortValuePtr);
  }

  // static OrtValueTensor createTensorWithData(dynamic data) {
  //   if (data is int) {
  //     return createTensorWithDataList(<int>[data], []);
  //   }
  //   if (data is double) {
  //     return createTensorWithDataList(<double>[data], []);
  //   }
  //   if (data is bool) {
  //     return createTensorWithDataList(<bool>[data], []);
  //   }
  //   if (data is String) {
  //     return _createTensorWithString(data);
  //   }
  //   throw Exception('Invalid element type');
  // }

  static MapEntry<ffi.Pointer<ffi.Void>, OrtValueTensor>  createTensorWithDataList(List data,
      [List<int>? shape]) {
    shape ??= data.shape;
    final element = data.element();
    var dataType = ONNXTensorElementDataType.undefined;
    ffi.Pointer<ffi.Void> dataPtr = ffi.nullptr;
    int dataSize = 0;
    int dataByteCount = 0;
    if (element is Uint8List) {
      final flattenData = data.flatten<int>();
      dataSize = flattenData.length;
      dataType = ONNXTensorElementDataType.uint8;
      dataPtr = (calloc<ffi.Uint8>(dataSize)
            ..asTypedList(dataSize).setRange(0, dataSize, flattenData))
          .cast();
      dataByteCount = dataSize;
    } else if (element is Int8List) {
      final flattenData = data.flatten<int>();
      dataSize = flattenData.length;
      dataType = ONNXTensorElementDataType.int8;
      dataPtr = (calloc<ffi.Int8>(dataSize)
            ..asTypedList(dataSize).setRange(0, dataSize, flattenData))
          .cast();
      dataByteCount = dataSize;
    } else if (element is Uint16List) {
      final flattenData = data.flatten<int>();
      dataSize = flattenData.length;
      dataType = ONNXTensorElementDataType.uint16;
      dataPtr = (calloc<ffi.Uint16>(dataSize)
            ..asTypedList(dataSize).setRange(0, dataSize, flattenData))
          .cast();
      dataByteCount = dataSize * 2;
    } else if (element is Int16List) {
      final flattenData = data.flatten<int>();
      dataSize = flattenData.length;
      dataType = ONNXTensorElementDataType.int16;
      dataPtr = (calloc<ffi.Int16>(dataSize)
            ..asTypedList(dataSize).setRange(0, dataSize, flattenData))
          .cast();
      dataByteCount = dataSize * 2;
    } else if (element is Uint32List) {
      final flattenData = data.flatten<int>();
      dataSize = flattenData.length;
      dataType = ONNXTensorElementDataType.uint32;
      dataPtr = (calloc<ffi.Uint32>(dataSize)
            ..asTypedList(dataSize).setRange(0, dataSize, flattenData))
          .cast();
      dataByteCount = dataSize * 4;
    } else if (element is Int32List) {
      final flattenData = data.flatten<int>();
      dataSize = flattenData.length;
      dataType = ONNXTensorElementDataType.int32;
      dataPtr = (calloc<ffi.Int32>(dataSize)
            ..asTypedList(dataSize).setRange(0, dataSize, flattenData))
          .cast();
      dataByteCount = dataSize * 4;
    } else if (element is Uint64List) {
      final flattenData = data.flatten<int>();
      dataSize = flattenData.length;
      dataType = ONNXTensorElementDataType.uint64;
      dataPtr = (calloc<ffi.Uint64>(dataSize)
            ..asTypedList(dataSize).setRange(0, dataSize, flattenData))
          .cast();
      dataByteCount = dataSize * 8;
    } else if (element is Int64List || element is int) {
      final flattenData = data.flatten<int>();
      dataSize = flattenData.length;
      dataType = ONNXTensorElementDataType.int64;
      dataPtr = (calloc<ffi.Int64>(dataSize)
            ..asTypedList(dataSize).setRange(0, dataSize, flattenData))
          .cast();
      dataByteCount = dataSize * 8;
    } else if (element is Float32List) {
      final flattenData = data.flatten<double>();
      dataSize = flattenData.length;
      dataType = ONNXTensorElementDataType.float;
      dataPtr = (calloc<ffi.Float>(dataSize)
            ..asTypedList(dataSize).setRange(0, dataSize, flattenData))
          .cast();
      dataByteCount = dataSize * 4;
    } else if (element is Float64List || element is double) {
      final flattenData = data.flatten<double>();
      dataSize = flattenData.length;
      dataType = ONNXTensorElementDataType.double;
      dataPtr = (calloc<ffi.Double>(dataSize)
            ..asTypedList(dataSize).setRange(0, dataSize, flattenData))
          .cast();
      dataByteCount = dataSize * 8;
    } else if (element is bool) {
      final flattenData = data.flatten<bool>();
      dataSize = flattenData.length;
      dataType = ONNXTensorElementDataType.bool;
      final ptr = calloc<ffi.Bool>(dataSize);
      for (int i = 0; i < dataSize; ++i) {
        ptr[i] = flattenData[i];
      }
      dataPtr = ptr.cast();
      dataByteCount = dataSize;
    // } else if (element is String) {
    //   return _createTensorWithStringList(data.cast<String>(), shape);
    } else {
      throw Exception('Invalid inputTensor element type.');
    }

    final shapeSize = shape.length;
    final shapePtr = calloc<ffi.Int64>(shapeSize);
    shapePtr.asTypedList(shapeSize).setRange(0, shapeSize, shape);

    final ortMemoryInfoPtrPtr = calloc<ffi.Pointer<bindings.OrtMemoryInfo>>();
    var statusPtr = OrtEnv.instance.ortApiPtr.ref.AllocatorGetInfo.asFunction<
            bindings.OrtStatusPtr Function(ffi.Pointer<bindings.OrtAllocator>,
                ffi.Pointer<ffi.Pointer<bindings.OrtMemoryInfo>>)>()(
        OrtAllocator.instance.ptr, ortMemoryInfoPtrPtr);
    OrtStatus.checkOrtStatus(statusPtr);
    // or
    // OrtEnv.instance.ortApiPtr.ref.CreateCpuMemoryInfo.asFunction<
    //         bindings.OrtStatusPtr Function(
    //             int, int, ffi.Pointer<ffi.Pointer<bindings.OrtMemoryInfo>>)>()(
    //     bindings.OrtAllocatorType.OrtDeviceAllocator,
    //     bindings.OrtMemType.OrtMemTypeCPU,
    //     ortMemoryInfoPtrPtr);
    final ortMemoryInfoPtr = ortMemoryInfoPtrPtr.value;
    final ortValuePtrPtr = calloc<ffi.Pointer<bindings.OrtValue>>();
    statusPtr = OrtEnv.instance.ortApiPtr.ref.CreateTensorWithDataAsOrtValue
            .asFunction<
                bindings.OrtStatusPtr Function(
                    ffi.Pointer<bindings.OrtMemoryInfo>,
                    ffi.Pointer<ffi.Void>,
                    int,
                    ffi.Pointer<ffi.Int64>,
                    int,
                    int,
                    ffi.Pointer<ffi.Pointer<bindings.OrtValue>>)>()(
        ortMemoryInfoPtr,
        dataPtr,
        dataByteCount,
        shapePtr,
        shapeSize,
        dataType.value,
        ortValuePtrPtr);
    OrtStatus.checkOrtStatus(statusPtr);
    final ortValuePtr = ortValuePtrPtr.value;
    calloc.free(shapePtr);
    // calloc.free(dataPtr);
    calloc.free(ortValuePtrPtr);
    calloc.free(ortMemoryInfoPtrPtr);
    return MapEntry(dataPtr, OrtValueTensor(ortValuePtr));
  }

  @override
  dynamic get value {
    if (_info._dimensionsCount == 0) {
      // scalar tensor
      switch (_info._tensorElementType) {
        case ONNXTensorElementDataType.uint8:
        case ONNXTensorElementDataType.int8:
        case ONNXTensorElementDataType.uint16:
        case ONNXTensorElementDataType.int16:
        case ONNXTensorElementDataType.uint32:
        case ONNXTensorElementDataType.int32:
        case ONNXTensorElementDataType.uint64:
        case ONNXTensorElementDataType.int64:
        case ONNXTensorElementDataType.float:
        case ONNXTensorElementDataType.double:
          return _getNumList(_ptr)[0];
        case ONNXTensorElementDataType.bool:
          return _getBoolList(_ptr)[0];
        case ONNXTensorElementDataType.string:
          return _getStringList(_ptr)[0];
        default:
          throw Exception('Extracting the value of an invalid Tensor.');
      }
    } else {
      // vector tensor
      switch (_info._tensorElementType) {
        case ONNXTensorElementDataType.uint8:
        case ONNXTensorElementDataType.int8:
        case ONNXTensorElementDataType.uint16:
        case ONNXTensorElementDataType.int16:
        case ONNXTensorElementDataType.uint32:
        case ONNXTensorElementDataType.int32:
        case ONNXTensorElementDataType.uint64:
        case ONNXTensorElementDataType.int64:
          return _getNumList(_ptr).reshape<int>(_info._tensorShape);
        case ONNXTensorElementDataType.float:
        case ONNXTensorElementDataType.double:
          return _getNumList(_ptr).reshape<double>(_info._tensorShape);
        case ONNXTensorElementDataType.bool:
          return _getBoolList(_ptr).reshape<bool>(_info._tensorShape);
        case ONNXTensorElementDataType.string:
          return _getStringList(_ptr).reshape<String>(_info._tensorShape);
        default:
          throw Exception('Extracting the value of an invalid Tensor.');
      }
    }
  }
}

class OrtValueSequence extends OrtValue {
  int _valueCount = 0;
  var _onnxType = ONNXType.unknown;
  OrtTensorTypeAndShapeInfo? _tensorInfo;

  // OrtTensorTypeAndShapeInfo? _firstMapKeyInfo;
  // OrtTensorTypeAndShapeInfo? _firstMapValueInfo;

  OrtValueSequence(ffi.Pointer<bindings.OrtValue> ptr) {
    _ptr = ptr;
    final valueCountPtr = calloc<ffi.Size>();
    var statusPtr = OrtEnv.instance.ortApiPtr.ref.GetValueCount.asFunction<
        bindings.OrtStatusPtr Function(ffi.Pointer<bindings.OrtValue>,
            ffi.Pointer<ffi.Size>)>()(_ptr, valueCountPtr);
    OrtStatus.checkOrtStatus(statusPtr);
    _valueCount = valueCountPtr.value;
    calloc.free(valueCountPtr);
    if (_valueCount <= 0) {
      return;
    }
    final firstElementPtrPtr = calloc<ffi.Pointer<bindings.OrtValue>>();
    final firstElementPtr = _getOrtValue(_ptr, 0, firstElementPtrPtr);
    final onnxTypePtr = calloc<ffi.Int32>();
    statusPtr = OrtEnv.instance.ortApiPtr.ref.GetValueType.asFunction<
        bindings.OrtStatusPtr Function(ffi.Pointer<bindings.OrtValue>,
            ffi.Pointer<ffi.Int32>)>()(firstElementPtr, onnxTypePtr);
    OrtStatus.checkOrtStatus(statusPtr);
    _onnxType = ONNXType.valueOf(onnxTypePtr.value);
    if (_onnxType == ONNXType.tensor) {
      _tensorInfo = OrtTensorTypeAndShapeInfo(firstElementPtr);
    } else if (_onnxType == ONNXType.map) {
      // final infoMap = _createMapInfo(firstElementPtr);
      // _firstMapKeyInfo = infoMap.entries.first.key;
      // _firstMapValueInfo = infoMap.entries.first.value;
    }
    _releaseOrtValue(firstElementPtr);
    calloc.free(firstElementPtrPtr);
    calloc.free(onnxTypePtr);
  }

  OrtValueSequence.fromAddress(int address) {
    _ptr = ffi.Pointer.fromAddress(address);
  }

  @override
  List<OrtValue>? get value {
    if (_onnxType == ONNXType.map) {
      final maps = <OrtValueMap>[];
      for (int i = 0; i < _valueCount; ++i) {
        final ortValuePtrPtr = calloc<ffi.Pointer<bindings.OrtValue>>();
        final ortValuePtr = _getOrtValue(_ptr, i, ortValuePtrPtr);
        maps.add(OrtValueMap(ortValuePtr));
        calloc.free(ortValuePtrPtr);
      }
      return maps;
    } else if (_onnxType == ONNXType.tensor) {
      switch (_tensorInfo?._tensorElementType) {
        case ONNXTensorElementDataType.string:
        case ONNXTensorElementDataType.int64:
        case ONNXTensorElementDataType.float:
        case ONNXTensorElementDataType.double:
          final tensors = <OrtValueTensor>[];
          for (int i = 0; i < _valueCount; ++i) {
            final ortValuePtrPtr = calloc<ffi.Pointer<bindings.OrtValue>>();
            final ortValuePtr = _getOrtValue(_ptr, i, ortValuePtrPtr);
            tensors.add(OrtValueTensor(ortValuePtr));
            calloc.free(ortValuePtrPtr);
          }
          return tensors;
        default:
          throw Exception(
              'Unsupported type in a sequence, found ${_tensorInfo?._tensorElementType}');
      }
    } else {
      throw Exception("Invalid element type found in sequence");
    }
  }
}

class OrtValueMap extends OrtValue {
  late OrtTensorTypeAndShapeInfo _keyInfo;
  late OrtTensorTypeAndShapeInfo _valueInfo;

  OrtValueMap(ffi.Pointer<bindings.OrtValue> ptr) {
    _ptr = ptr;
    final infoMap = _createMapInfo(ptr);
    _keyInfo = infoMap.entries.first.key;
    _valueInfo = infoMap.entries.first.value;
  }

  OrtValueMap.fromAddress(int address) {
    _ptr = ffi.Pointer.fromAddress(address);
  }

  @override
  Map get value {
    final keys = _getMapKeys();
    final values = _getMapValues();
    final map = {};
    for (int i = 0; i < keys.length; ++i) {
      map[keys[i]] = values[i];
    }
    return map;
  }

  List<dynamic> _getMapKeys() {
    switch (_keyInfo._tensorElementType) {
      case ONNXTensorElementDataType.string:
        return _getStringListWithIndex(0);
      case ONNXTensorElementDataType.int64:
        return _getNumListWithIndex(0);
      default:
        throw Exception(
            'Invalid or unknown valueType: ${_keyInfo._tensorElementType}');
    }
  }

  List<String> _getStringListWithIndex(int index) {
    final ortValuePtrPtr = calloc<ffi.Pointer<bindings.OrtValue>>();
    final ortValuePtr = _getOrtValue(_ptr, index, ortValuePtrPtr);
    final list = _getStringList(ortValuePtr);
    _releaseOrtValue(ortValuePtr);
    calloc.free(ortValuePtrPtr);
    return list;
  }

  List<num> _getNumListWithIndex(int index) {
    final ortValuePtrPtr = calloc<ffi.Pointer<bindings.OrtValue>>();
    final ortValuePtr = _getOrtValue(_ptr, index, ortValuePtrPtr);
    final list = _getNumList(ortValuePtr);
    _releaseOrtValue(ortValuePtr);
    calloc.free(ortValuePtrPtr);
    return list;
  }

  List<Object> _getMapValues() {
    switch (_valueInfo._tensorElementType) {
      case ONNXTensorElementDataType.string:
        return _getStringListWithIndex(1);
      case ONNXTensorElementDataType.int64:
      case ONNXTensorElementDataType.float:
      case ONNXTensorElementDataType.double:
        return _getNumListWithIndex(1);
      default:
        throw Exception(
            'Invalid or unknown valueType: ${_keyInfo._tensorElementType}');
    }
  }

  int get size => _keyInfo._tensorShapeElementCount;
}

class OrtValueSparseTensor extends OrtValue {
  late OrtTensorTypeAndShapeInfo _info;
  late OrtSparseFormat _ortSparseFormat;

  OrtValueSparseTensor(ffi.Pointer<bindings.OrtValue> ptr) {
    _ptr = ptr;
    _info = OrtTensorTypeAndShapeInfo(ptr);
    final ortSparseFormatPtr = calloc<ffi.Int32>();
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.GetSparseTensorFormat
        .asFunction<
            bindings.OrtStatusPtr Function(ffi.Pointer<bindings.OrtValue>,
                ffi.Pointer<ffi.Int32>)>()(ptr, ortSparseFormatPtr);
    OrtStatus.checkOrtStatus(statusPtr);
    _ortSparseFormat = OrtSparseFormat.valueOf(ortSparseFormatPtr.value);
    calloc.free(ortSparseFormatPtr);
  }

  OrtValueSparseTensor.fromAddress(int address) {
    _ptr = ffi.Pointer.fromAddress(address);
  }

  @override
  Object? get value {
    switch (_ortSparseFormat) {
      case OrtSparseFormat.coo:
        // TODO: Handle this case.
        break;
      case OrtSparseFormat.csrc:
        // TODO: Handle this case.
        break;
      case OrtSparseFormat.blockSparse:
        // TODO: Handle this case.
        break;
      case OrtSparseFormat.undefined:
        throw Exception('Undefined sparsity type in this sparse tensor.');
    }
  }
}

class OrtTensorTypeAndShapeInfo {
  int _dimensionsCount = 0;
  int _tensorShapeElementCount = 0;
  ONNXTensorElementDataType _tensorElementType =
      ONNXTensorElementDataType.undefined;
  List<int> _tensorShape = [];

  OrtTensorTypeAndShapeInfo(ffi.Pointer<bindings.OrtValue> ortValuePtr) {
    final infoPtrPtr =
        calloc<ffi.Pointer<bindings.OrtTensorTypeAndShapeInfo>>();
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.GetTensorTypeAndShape
            .asFunction<
                bindings.OrtStatusPtr Function(
                    ffi.Pointer<bindings.OrtValue>,
                    ffi.Pointer<
                        ffi.Pointer<bindings.OrtTensorTypeAndShapeInfo>>)>()(
        ortValuePtr, infoPtrPtr);
    OrtStatus.checkOrtStatus(statusPtr);
    final infoPtr = infoPtrPtr.value;
    _tensorElementType = _getTensorElementType(infoPtr);
    // shape
    _dimensionsCount = _getDimensionsCount(infoPtr);
    _tensorShape = _getDimensions(infoPtr, _dimensionsCount);
    _tensorShapeElementCount = _getTensorShapeElementCount(infoPtr);
    _releaseTensorTypeAndShapeInfo(infoPtr);
    calloc.free(infoPtrPtr);
  }

  static ONNXTensorElementDataType _getTensorElementType(
      ffi.Pointer<bindings.OrtTensorTypeAndShapeInfo> infoPtr) {
    final onnxTensorElementDataTypePtr = calloc<ffi.Int32>();
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.GetTensorElementType
            .asFunction<
                bindings.OrtStatusPtr Function(
                    ffi.Pointer<bindings.OrtTensorTypeAndShapeInfo>,
                    ffi.Pointer<ffi.Int32>)>()(
        infoPtr, onnxTensorElementDataTypePtr);
    OrtStatus.checkOrtStatus(statusPtr);
    final onnxTensorElementDataType = onnxTensorElementDataTypePtr.value;
    calloc.free(onnxTensorElementDataTypePtr);
    return ONNXTensorElementDataType.valueOf(onnxTensorElementDataType);
  }

  static _releaseTensorTypeAndShapeInfo(
      ffi.Pointer<bindings.OrtTensorTypeAndShapeInfo> infoPtr) {
    OrtEnv.instance.ortApiPtr.ref.ReleaseTensorTypeAndShapeInfo.asFunction<
        void Function(
            ffi.Pointer<bindings.OrtTensorTypeAndShapeInfo>)>()(infoPtr);
  }

  static int _getDimensionsCount(
      ffi.Pointer<bindings.OrtTensorTypeAndShapeInfo> infoPtr) {
    final countPtr = calloc<ffi.Size>();
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.GetDimensionsCount
        .asFunction<
            bindings.OrtStatusPtr Function(
                ffi.Pointer<bindings.OrtTensorTypeAndShapeInfo>,
                ffi.Pointer<ffi.Size>)>()(infoPtr, countPtr);
    OrtStatus.checkOrtStatus(statusPtr);
    final count = countPtr.value;
    calloc.free(countPtr);
    return count;
  }

  static List<int> _getDimensions(
      ffi.Pointer<bindings.OrtTensorTypeAndShapeInfo> infoPtr, int length) {
    final dimensionsPtr = calloc<ffi.Int64>(length);
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.GetDimensions.asFunction<
        bindings.OrtStatusPtr Function(
            ffi.Pointer<bindings.OrtTensorTypeAndShapeInfo>,
            ffi.Pointer<ffi.Int64>,
            int)>()(infoPtr, dimensionsPtr, length);
    OrtStatus.checkOrtStatus(statusPtr);
    final dimensions =
        List<int>.generate(length, (index) => dimensionsPtr[index]);
    calloc.free(dimensionsPtr);
    return dimensions;
  }

  static int _getTensorShapeElementCount(
      ffi.Pointer<bindings.OrtTensorTypeAndShapeInfo> infoPtr) {
    final countPtr = calloc<ffi.Size>();
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.GetTensorShapeElementCount
        .asFunction<
            bindings.OrtStatusPtr Function(
                ffi.Pointer<bindings.OrtTensorTypeAndShapeInfo>,
                ffi.Pointer<ffi.Size>)>()(infoPtr, countPtr);
    OrtStatus.checkOrtStatus(statusPtr);
    final count = countPtr.value;
    calloc.free(countPtr);
    return count;
  }
}

enum ONNXTensorElementDataType {
  undefined(bindings
      .ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_UNDEFINED),
  float(bindings.ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT),
  uint8(bindings.ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT8),
  int8(bindings.ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_INT8),
  uint16(
      bindings.ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT16),
  int16(bindings.ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_INT16),
  int32(bindings.ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32),
  int64(bindings.ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64),
  string(
      bindings.ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_STRING),
  bool(bindings.ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL),
  float16(
      bindings.ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT16),
  double(
      bindings.ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_DOUBLE),
  uint32(
      bindings.ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT32),
  uint64(
      bindings.ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT64),
  complex64(bindings
      .ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_COMPLEX64),
  complex128(bindings
      .ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_COMPLEX128),
  bFloat16(bindings
      .ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_BFLOAT16);

  final int value;

  const ONNXTensorElementDataType(this.value);

  static ONNXTensorElementDataType valueOf(int type) {
    switch (type) {
      case bindings
            .ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT:
        return ONNXTensorElementDataType.float;
      case bindings
            .ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT8:
        return ONNXTensorElementDataType.uint8;
      case bindings
            .ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_INT8:
        return ONNXTensorElementDataType.int8;
      case bindings
            .ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT16:
        return ONNXTensorElementDataType.uint16;
      case bindings
            .ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_INT16:
        return ONNXTensorElementDataType.int16;
      case bindings
            .ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32:
        return ONNXTensorElementDataType.int32;
      case bindings
            .ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64:
        return ONNXTensorElementDataType.int64;
      case bindings
            .ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_STRING:
        return ONNXTensorElementDataType.string;
      case bindings
            .ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL:
        return ONNXTensorElementDataType.bool;
      case bindings
            .ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT16:
        return ONNXTensorElementDataType.float16;
      case bindings
            .ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_DOUBLE:
        return ONNXTensorElementDataType.double;
      case bindings
            .ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT32:
        return ONNXTensorElementDataType.uint32;
      case bindings
            .ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT64:
        return ONNXTensorElementDataType.uint64;
      case bindings
            .ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_COMPLEX64:
        return ONNXTensorElementDataType.complex64;
      case bindings
            .ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_COMPLEX128:
        return ONNXTensorElementDataType.complex128;
      case bindings
            .ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_BFLOAT16:
        return ONNXTensorElementDataType.bFloat16;
      default:
        return ONNXTensorElementDataType.undefined;
    }
  }
}

enum ONNXType {
  unknown(bindings.ONNXType.ONNX_TYPE_UNKNOWN),
  tensor(bindings.ONNXType.ONNX_TYPE_TENSOR),
  sequence(bindings.ONNXType.ONNX_TYPE_SEQUENCE),
  map(bindings.ONNXType.ONNX_TYPE_MAP),
  opaque(bindings.ONNXType.ONNX_TYPE_OPAQUE),
  sparseTensor(bindings.ONNXType.ONNX_TYPE_SPARSETENSOR),
  optional(bindings.ONNXType.ONNX_TYPE_OPTIONAL);

  final int value;

  const ONNXType(this.value);

  static ONNXType valueOf(int type) {
    switch (type) {
      case bindings.ONNXType.ONNX_TYPE_TENSOR:
        return ONNXType.tensor;
      case bindings.ONNXType.ONNX_TYPE_SEQUENCE:
        return ONNXType.sequence;
      case bindings.ONNXType.ONNX_TYPE_MAP:
        return ONNXType.map;
      case bindings.ONNXType.ONNX_TYPE_OPAQUE:
        return ONNXType.opaque;
      case bindings.ONNXType.ONNX_TYPE_SPARSETENSOR:
        return ONNXType.sparseTensor;
      case bindings.ONNXType.ONNX_TYPE_OPTIONAL:
        return ONNXType.optional;
      default:
        return ONNXType.unknown;
    }
  }
}

enum OrtSparseFormat {
  undefined(bindings.OrtSparseFormat.ORT_SPARSE_UNDEFINED),
  coo(bindings.OrtSparseFormat.ORT_SPARSE_COO),
  csrc(bindings.OrtSparseFormat.ORT_SPARSE_CSRC),
  blockSparse(bindings.OrtSparseFormat.ORT_SPARSE_BLOCK_SPARSE);

  final int value;

  const OrtSparseFormat(this.value);

  static OrtSparseFormat valueOf(int type) {
    switch (type) {
      case bindings.OrtSparseFormat.ORT_SPARSE_COO:
        return OrtSparseFormat.coo;
      case bindings.OrtSparseFormat.ORT_SPARSE_CSRC:
        return OrtSparseFormat.csrc;
      case bindings.OrtSparseFormat.ORT_SPARSE_BLOCK_SPARSE:
        return OrtSparseFormat.blockSparse;
      default:
        return OrtSparseFormat.undefined;
    }
  }
}
