// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:d_serializer/d_serializer.dart';
import 'package:d_serializer_builder/src/utils.dart';
import 'package:source_gen/source_gen.dart';

class SerializableGenerator extends GeneratorForAnnotation<Serializable> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@Serializable can only be applied to classes',
        element: element,
      );
    }

    final String className = element.displayName;
    final String? rename = _readOptionalString(annotation, 'rename');
    final String? discriminator = _readOptionalString(annotation, 'discriminator');
    final String? typeField = _readOptionalString(annotation, 'typeField');
    final bool strict = _readOptionalBool(annotation, 'strict') ?? false;
    final JsonNaming naming = _readNaming(annotation);
    final String resolvedDiscriminator = discriminator ?? rename ?? className;

    final List<FieldElement> fields =
        element.fields.where((FieldElement f) => !f.isStatic && !f.isPrivate).toList();

    final List<String> toJsonEntries = <String>[];
    final List<String> fromJsonParams = <String>[];
    final List<String> fromJsonGuards = <String>[];
    final List<String> knownKeys = <String>[];

    if (typeField != null && typeField.isNotEmpty) {
      knownKeys.add(typeField);
      fromJsonGuards.add(
        "if (json['$typeField'] != '$resolvedDiscriminator') { throw ArgumentError('Invalid discriminator for $className at $typeField: expected $resolvedDiscriminator'); }",
      );
      toJsonEntries.add("'$typeField': '$resolvedDiscriminator',");
    }

    for (final FieldElement field in fields) {
      final String fieldName = field.displayName;
      final DartType type = field.type;
      final String typeStr = type.toString();
      final String defaultJsonKey = naming == JsonNaming.snakeCase ? toSnakeCase(fieldName) : fieldName;
      final List<_FormatSpec> formats = _getFormatAnnotations(field);

      final ConstantReader? jsonKeyAnnotation = _getJsonKeyAnnotation(field);
      if (jsonKeyAnnotation != null) {
        final ConstantReader ignoreValue = jsonKeyAnnotation.read('ignore');
        if (ignoreValue.isBool && ignoreValue.boolValue == true) {
          continue;
        }

        String actualJsonKey = defaultJsonKey;
        final ConstantReader nameValue = jsonKeyAnnotation.read('name');
        if (nameValue.isString && nameValue.stringValue.isNotEmpty) {
          actualJsonKey = nameValue.stringValue;
        }

        final bool useEnumIndex = _readOptionalBool(jsonKeyAnnotation, 'useEnumIndex') ?? false;
        final String? defaultValueCode = _readDefaultValueCode(jsonKeyAnnotation);
        final String? converter = _readOptionalString(jsonKeyAnnotation, 'converter');
        final bool requiredKey = _readOptionalBool(jsonKeyAnnotation, 'requiredKey') ?? false;
        final String? unknownEnumValue = _readOptionalString(jsonKeyAnnotation, 'unknownEnumValue');

        knownKeys.add(actualJsonKey);
        if (requiredKey) {
          fromJsonGuards.add(
            "if (!json.containsKey('$actualJsonKey') || json['$actualJsonKey'] == null) { throw ArgumentError('Missing required field $className.$fieldName ($actualJsonKey)'); }",
          );
        }

        _addFieldSerialization(
          toJsonEntries,
          fromJsonParams,
          className,
          fieldName,
          actualJsonKey,
          typeStr,
          type,
          useEnumIndex,
          defaultValueCode,
          converter,
          unknownEnumValue,
          formats,
        );
        continue;
      }

      knownKeys.add(defaultJsonKey);
      _addFieldSerialization(
        toJsonEntries,
        fromJsonParams,
        className,
        fieldName,
        defaultJsonKey,
        typeStr,
        type,
        false,
        null,
        null,
        null,
        formats,
      );
    }

    if (strict) {
      final String keys = knownKeys.map((String item) => "'$item'").join(', ');
      fromJsonGuards.add(
        "const Set<String> _allowedKeys = <String>{$keys}; for (final String key in json.keys) { if (!_allowedKeys.contains(key)) { throw ArgumentError('Unknown field for $className: \$key'); } }",
      );
    }

    final String toJsonBody = 'return <String, dynamic>{\n${toJsonEntries.join('\n')}\n};';
    final String fromJsonBody = 'return $className(\n${fromJsonParams.join('\n')}\n);';
    final String guards = fromJsonGuards.isEmpty ? '' : '${fromJsonGuards.join('\n  ')}\n  ';

    return '''
// GENERATED CODE - DO NOT MODIFY BY HAND

$className ${className}FromJson(Map<String, dynamic> json) {
  $guards$fromJsonBody
}

Map<String, dynamic> ${className}ToJson($className value) {
  return value.toJson();
}

void register${className}Serializer() {
  Serializer.register<$className>(
    fromJson: ${className}FromJson,
    toJson: ${className}ToJson,
  );
}

extension ${className}Serializer on $className {
  Map<String, dynamic> toJson() {
    $toJsonBody
  }
}
''';
  }

  void _addFieldSerialization(
    List<String> toJsonEntries,
    List<String> fromJsonParams,
    String className,
    String fieldName,
    String jsonKey,
    String typeStr,
    DartType type,
    bool useEnumIndex,
    String? defaultValueCode,
    String? converter,
    String? unknownEnumValue,
    List<_FormatSpec> formats,
  ) {
    _validateFormatCompatibility(className, fieldName, typeStr, formats);

    if (converter != null && converter.isNotEmpty) {
      final bool nullable = type.nullabilitySuffix.name != 'none';
      String toExpr;
      if (nullable) {
        toExpr =
            "$fieldName == null ? null : ${converter}ToJson($fieldName as ${_nonNullableType(typeStr)})";
      } else {
        toExpr = "${converter}ToJson($fieldName)";
      }

      String fromExpr = nullable
          ? "json['$jsonKey'] == null ? null : ${converter}FromJson(json['$jsonKey'])"
          : "${converter}FromJson(json['$jsonKey'])";
      if (defaultValueCode != null) {
        fromExpr = "json['$jsonKey'] == null ? $defaultValueCode : $fromExpr";
      }
      toExpr = _applyFormattersToJsonExpr(toExpr, typeStr, formats);
      fromExpr = _applyFormattersFromJsonExpr(fromExpr, typeStr, formats);
      fromJsonParams.add('$fieldName: $fromExpr,');
      toJsonEntries.add("'$jsonKey': $toExpr,");
      return;
    }

    String toExpr;
    String fromExpr;

    if (type.isDartCoreList) {
      final DartType typeArg = (type as InterfaceType).typeArguments.first;
      final String toJsonInner = _toJsonExpr('e', typeArg.toString(), typeArg, useEnumIndex: false, unknownEnumValue: null);
      final String fromJsonInner = _fromJsonExpr('e', typeArg.toString(), typeArg, useEnumIndex: false, unknownEnumValue: null);
      toExpr = '($fieldName as List).map((e) => $toJsonInner).toList()';
      fromExpr = "(json['$jsonKey'] as List).map((e) => $fromJsonInner).toList()";
    } else if (type.isDartCoreSet) {
      final DartType typeArg = (type as InterfaceType).typeArguments.first;
      final String toJsonInner = _toJsonExpr('e', typeArg.toString(), typeArg, useEnumIndex: false, unknownEnumValue: null);
      final String fromJsonInner = _fromJsonExpr('e', typeArg.toString(), typeArg, useEnumIndex: false, unknownEnumValue: null);
      toExpr = '($fieldName as Set).map((e) => $toJsonInner).toList()';
      fromExpr = "((json['$jsonKey'] as List).map((e) => $fromJsonInner)).toSet()";
    } else if (type.isDartCoreMap) {
      final DartType valueType = (type as InterfaceType).typeArguments.last;
      final String toJsonInner = _toJsonExpr('v', valueType.toString(), valueType, useEnumIndex: false, unknownEnumValue: null);
      final String fromJsonInner = _fromJsonExpr('v', valueType.toString(), valueType, useEnumIndex: false, unknownEnumValue: null);
      toExpr = '($fieldName as Map).map((k, v) => MapEntry(k.toString(), $toJsonInner))';
      fromExpr = "(json['$jsonKey'] as Map).map((k, v) => MapEntry(k.toString(), $fromJsonInner))";
    } else if (type.element?.name == 'DateTime') {
      if (typeStr.endsWith('?')) {
        toExpr = "$fieldName == null ? null : ($fieldName as DateTime).toIso8601String()";
        fromExpr = "json['$jsonKey'] == null ? null : DateTime.parse(json['$jsonKey'] as String)";
      } else {
        toExpr = '$fieldName.toIso8601String()';
        fromExpr = "DateTime.parse(json['$jsonKey'] as String)";
      }
    } else if (type.element?.name == 'Uri') {
      if (typeStr.endsWith('?')) {
        toExpr = "$fieldName == null ? null : ($fieldName as Uri).toString()";
        fromExpr = "json['$jsonKey'] == null ? null : Uri.parse(json['$jsonKey'] as String)";
      } else {
        toExpr = '$fieldName.toString()';
        fromExpr = "Uri.parse(json['$jsonKey'] as String)";
      }
    } else if (type.element?.name == 'BigInt') {
      if (typeStr.endsWith('?')) {
        toExpr = "$fieldName == null ? null : ($fieldName as BigInt).toString()";
        fromExpr = "json['$jsonKey'] == null ? null : BigInt.parse(json['$jsonKey'] as String)";
      } else {
        toExpr = '$fieldName.toString()';
        fromExpr = "BigInt.parse(json['$jsonKey'] as String)";
      }
    } else if (type.element?.name == 'Duration') {
      if (typeStr.endsWith('?')) {
        toExpr = "$fieldName == null ? null : ($fieldName as Duration).inMicroseconds";
        fromExpr = "json['$jsonKey'] == null ? null : Duration(microseconds: (json['$jsonKey'] as num).toInt())";
      } else {
        toExpr = '$fieldName.inMicroseconds';
        fromExpr = "Duration(microseconds: (json['$jsonKey'] as num).toInt())";
      }
    } else if (type.element?.kind == ElementKind.ENUM) {
      toExpr = _enumToJsonExpr(fieldName, typeStr, useEnumIndex);
      fromExpr = _enumFromJsonExpr(
        "json['$jsonKey']",
        typeStr,
        useEnumIndex,
        unknownEnumValue,
        nullable: typeStr.endsWith('?'),
      );
    } else if (type.isDartCoreInt) {
      toExpr = fieldName;
      fromExpr = "(json['$jsonKey'] as num).toInt()";
    } else if (type.isDartCoreDouble) {
      toExpr = fieldName;
      fromExpr = "(json['$jsonKey'] as num).toDouble()";
    } else if (type.isDartCoreString || type.isDartCoreBool) {
      toExpr = fieldName;
      fromExpr = "json['$jsonKey'] as $typeStr";
    } else if (type.element?.name == 'dynamic') {
      toExpr = fieldName;
      fromExpr = "json['$jsonKey']";
    } else {
      toExpr = '$fieldName.toJson()';
      fromExpr = "${typeStr}FromJson(json['$jsonKey'] as Map<String, dynamic>)";
    }

    if (defaultValueCode != null) {
      fromExpr = "json['$jsonKey'] == null ? $defaultValueCode : $fromExpr";
    }

    toExpr = _applyFormattersToJsonExpr(toExpr, typeStr, formats);
    fromExpr = _applyFormattersFromJsonExpr(fromExpr, typeStr, formats);

    toJsonEntries.add("'$jsonKey': $toExpr,");
    fromJsonParams.add('$fieldName: $fromExpr,');
  }

  String _enumToJsonExpr(String fieldName, String typeStr, bool useEnumIndex) {
    if (typeStr.endsWith('?')) {
      final String cleanType = _nonNullableType(typeStr);
      if (useEnumIndex) {
        return "$fieldName == null ? null : ($fieldName as $cleanType).index";
      }
      return "$fieldName == null ? null : ($fieldName as $cleanType).name";
    }
    return useEnumIndex ? '$fieldName.index' : '$fieldName.name';
  }

  String _enumFromJsonExpr(
    String valueExpr,
    String typeStr,
    bool useEnumIndex,
    String? unknownEnumValue, {
    required bool nullable,
  }) {
    final String enumType = _nonNullableType(typeStr);
    final String unknownExpr = unknownEnumValue == null
        ? (nullable ? 'null' : 'throw ArgumentError(\'Unknown enum value for $enumType\')')
        : "$enumType.values.byName('$unknownEnumValue')";

    if (useEnumIndex) {
      final String parsed = "(() { final int _i = ($valueExpr as num).toInt(); if (_i < 0 || _i >= $enumType.values.length) return $unknownExpr; return $enumType.values[_i]; })()";
      return nullable
          ? "$valueExpr == null ? null : $parsed"
          : parsed;
    }

    final String parsed = "$enumType.values.firstWhere((e) => e.name == ($valueExpr as String), orElse: () => $unknownExpr)";
    return nullable
        ? "$valueExpr == null ? null : $parsed"
        : parsed;
  }

  ConstantReader? _getJsonKeyAnnotation(FieldElement field) {
    for (final ElementAnnotation annotation in field.metadata.annotations) {
      if (annotation.element?.displayName == 'JsonKey') {
        return ConstantReader(annotation.computeConstantValue());
      }
    }
    return null;
  }

  List<_FormatSpec> _getFormatAnnotations(FieldElement field) {
    final List<_FormatSpec> formats = <_FormatSpec>[];
    for (final ElementAnnotation annotation in field.metadata.annotations) {
      if (annotation.element?.enclosingElement?.displayName != 'Format') {
        continue;
      }
      final ConstantReader reader = ConstantReader(annotation.computeConstantValue());
      final String? kind = _readOptionalString(reader, 'kind');
      if (kind == null || kind.isEmpty) {
        continue;
      }
      final String? pattern = _readOptionalString(reader, 'pattern');
      if (kind == 'custom' && (pattern == null || pattern.trim().isEmpty)) {
        throw InvalidGenerationSourceError(
          'Invalid @Format.custom on ${field.enclosingElement.displayName}.${field.displayName}: custom formatter name cannot be empty.',
          element: field,
        );
      }
      formats.add(_FormatSpec(kind: kind, pattern: pattern));
    }
    return formats;
  }

  void _validateFormatCompatibility(
    String className,
    String fieldName,
    String typeStr,
    List<_FormatSpec> formats,
  ) {
    final String baseType = _nonNullableType(typeStr);
    for (final _FormatSpec format in formats) {
      switch (format.kind) {
        case 'trim':
        case 'uppercase':
        case 'lowercase':
          if (baseType != 'String') {
            throw InvalidGenerationSourceError(
              'Invalid @Format.${format.kind} on $className.$fieldName: only String/String? fields are supported.',
            );
          }
          break;
        case 'date':
          if (baseType != 'DateTime') {
            throw InvalidGenerationSourceError(
              'Invalid @Format.date on $className.$fieldName: only DateTime/DateTime? fields are supported.',
            );
          }
          if (format.pattern == null || format.pattern!.isEmpty) {
            throw InvalidGenerationSourceError(
              'Invalid @Format.date on $className.$fieldName: pattern is required.',
            );
          }
          break;
      }
    }
  }

  String _applyFormattersToJsonExpr(
    String expr,
    String typeStr,
    List<_FormatSpec> formats,
  ) {
    if (formats.isEmpty) {
      return expr;
    }

    final bool nullable = typeStr.endsWith('?');
    final String baseType = _nonNullableType(typeStr);
    String formatted = expr;

    for (final _FormatSpec format in formats) {
      switch (format.kind) {
        case 'trim':
          if (baseType != 'String') continue;
          formatted = nullable
              ? '($formatted == null ? null : ($formatted as String).trim())'
              : '(($formatted) as String).trim()';
          break;
        case 'uppercase':
          if (baseType != 'String') continue;
          formatted = nullable
              ? '($formatted == null ? null : ($formatted as String).toUpperCase())'
              : '(($formatted) as String).toUpperCase()';
          break;
        case 'lowercase':
          if (baseType != 'String') continue;
          formatted = nullable
              ? '($formatted == null ? null : ($formatted as String).toLowerCase())'
              : '(($formatted) as String).toLowerCase()';
          break;
        case 'date':
          if (baseType != 'DateTime' || format.pattern == null) continue;
          final String patternLiteral = _literalToCode(format.pattern);
          formatted = nullable
              ? '($formatted == null ? null : Serializer.formatDate(($formatted as DateTime), $patternLiteral))'
              : 'Serializer.formatDate((($formatted) as DateTime), $patternLiteral)';
          break;
        case 'custom':
          if (format.pattern == null || format.pattern!.isEmpty) continue;
          final String formatterName = format.pattern!;
          formatted = nullable
              ? '($formatted == null ? null : ${formatterName}FormatToJson($formatted))'
              : '${formatterName}FormatToJson($formatted)';
          break;
      }
    }
    return formatted;
  }

  String _applyFormattersFromJsonExpr(
    String expr,
    String typeStr,
    List<_FormatSpec> formats,
  ) {
    if (formats.isEmpty) {
      return expr;
    }

    final bool nullable = typeStr.endsWith('?');
    final String baseType = _nonNullableType(typeStr);
    String formatted = expr;

    for (final _FormatSpec format in formats) {
      switch (format.kind) {
        case 'trim':
          if (baseType != 'String') continue;
          formatted = nullable
              ? '($formatted == null ? null : ($formatted as String).trim())'
              : '(($formatted) as String).trim()';
          break;
        case 'uppercase':
          if (baseType != 'String') continue;
          formatted = nullable
              ? '($formatted == null ? null : ($formatted as String).toUpperCase())'
              : '(($formatted) as String).toUpperCase()';
          break;
        case 'lowercase':
          if (baseType != 'String') continue;
          formatted = nullable
              ? '($formatted == null ? null : ($formatted as String).toLowerCase())'
              : '(($formatted) as String).toLowerCase()';
          break;
        case 'date':
          if (baseType != 'DateTime' || format.pattern == null) continue;
          final String patternLiteral = _literalToCode(format.pattern);
          formatted = nullable
              ? '($formatted == null ? null : Serializer.parseDate(($formatted as String), $patternLiteral))'
              : 'Serializer.parseDate((($formatted) as String), $patternLiteral)';
          break;
        case 'custom':
          if (format.pattern == null || format.pattern!.isEmpty) continue;
          final String formatterName = format.pattern!;
          formatted = nullable
              ? '($formatted == null ? null : ${formatterName}FormatFromJson($formatted))'
              : '${formatterName}FormatFromJson($formatted)';
          break;
      }
    }
    return formatted;
  }

  String _toJsonExpr(
    String expr,
    String typeStr,
    DartType type, {
    required bool useEnumIndex,
    required String? unknownEnumValue,
  }) {
    if (type is InterfaceType && type.isDartCoreList) {
      final DartType typeArg = type.typeArguments.first;
      return '($expr as List).map((e) => ${_toJsonExpr('e', typeArg.toString(), typeArg, useEnumIndex: false, unknownEnumValue: null)}).toList()';
    }
    if (type is InterfaceType && type.isDartCoreSet) {
      final DartType typeArg = type.typeArguments.first;
      return '($expr as Set).map((e) => ${_toJsonExpr('e', typeArg.toString(), typeArg, useEnumIndex: false, unknownEnumValue: null)}).toList()';
    }
    if (type is InterfaceType && type.isDartCoreMap) {
      final DartType valueType = type.typeArguments.last;
      return '($expr as Map).map((k, v) => MapEntry(k.toString(), ${_toJsonExpr('v', valueType.toString(), valueType, useEnumIndex: false, unknownEnumValue: null)}))';
    }
    if (type.element?.name == 'DateTime') return '$expr.toIso8601String()';
    if (type.element?.name == 'Uri') return '$expr.toString()';
    if (type.element?.name == 'BigInt') return '$expr.toString()';
    if (type.element?.name == 'Duration') return '$expr.inMicroseconds';
    if (type.element?.kind == ElementKind.ENUM) return useEnumIndex ? '$expr.index' : '$expr.name';
    if (type.isDartCoreInt ||
        type.isDartCoreDouble ||
        type.isDartCoreString ||
        type.isDartCoreBool ||
        type.element?.name == 'dynamic') {
      return expr;
    }
    return '$expr.toJson()';
  }

  String _fromJsonExpr(
    String expr,
    String typeStr,
    DartType type, {
    required bool useEnumIndex,
    required String? unknownEnumValue,
  }) {
    if (type is InterfaceType && type.isDartCoreList) {
      final DartType typeArg = type.typeArguments.first;
      return '($expr as List).map((e) => ${_fromJsonExpr('e', typeArg.toString(), typeArg, useEnumIndex: false, unknownEnumValue: null)}).toList()';
    }
    if (type is InterfaceType && type.isDartCoreSet) {
      final DartType typeArg = type.typeArguments.first;
      return '($expr as List).map((e) => ${_fromJsonExpr('e', typeArg.toString(), typeArg, useEnumIndex: false, unknownEnumValue: null)}).toSet()';
    }
    if (type is InterfaceType && type.isDartCoreMap) {
      final DartType valueType = type.typeArguments.last;
      return '($expr as Map).map((k, v) => MapEntry(k.toString(), ${_fromJsonExpr('v', valueType.toString(), valueType, useEnumIndex: false, unknownEnumValue: null)}))';
    }
    if (type.element?.name == 'DateTime') return 'DateTime.parse($expr as String)';
    if (type.element?.name == 'Uri') return 'Uri.parse($expr as String)';
    if (type.element?.name == 'BigInt') return 'BigInt.parse($expr as String)';
    if (type.element?.name == 'Duration') return 'Duration(microseconds: ($expr as num).toInt())';
    if (type.element?.kind == ElementKind.ENUM) {
      return _enumFromJsonExpr(expr, typeStr, useEnumIndex, unknownEnumValue, nullable: typeStr.endsWith('?'));
    }
    if (type.isDartCoreInt) return '($expr as num).toInt()';
    if (type.isDartCoreDouble) return '($expr as num).toDouble()';
    if (type.isDartCoreString || type.isDartCoreBool || type.element?.name == 'dynamic') {
      return '$expr as $typeStr';
    }
    return '${typeStr}FromJson($expr as Map<String, dynamic>)';
  }

  String _nonNullableType(String typeStr) {
    return typeStr.endsWith('?') ? typeStr.substring(0, typeStr.length - 1) : typeStr;
  }

  String? _readOptionalString(ConstantReader reader, String field) {
    final ConstantReader? value = reader.peek(field);
    if (value == null || value.isNull || !value.isString) {
      return null;
    }
    return value.stringValue;
  }

  bool? _readOptionalBool(ConstantReader reader, String field) {
    final ConstantReader? value = reader.peek(field);
    if (value == null || value.isNull || !value.isBool) {
      return null;
    }
    return value.boolValue;
  }

  JsonNaming _readNaming(ConstantReader annotation) {
    final ConstantReader? value = annotation.peek('naming');
    if (value == null || value.isNull) {
      return JsonNaming.none;
    }
    final String name = value.revive().accessor;
    if (name == 'snakeCase') {
      return JsonNaming.snakeCase;
    }
    return JsonNaming.none;
  }

  String? _readDefaultValueCode(ConstantReader annotation) {
    final ConstantReader? value = annotation.peek('defaultValue');
    if (value == null || value.isNull) {
      return null;
    }
    return _literalToCode(value.literalValue);
  }

  String _literalToCode(Object? value) {
    if (value == null) {
      return 'null';
    }
    if (value is String) {
      final String escaped = value
          .replaceAll(r'\\', r'\\\\')
          .replaceAll("'", r"\\'")
          .replaceAll('\n', r'\\n');
      return "'$escaped'";
    }
    if (value is bool || value is num) {
      return value.toString();
    }
    if (value is List) {
      return '<dynamic>[${value.map(_literalToCode).join(', ')}]';
    }
    if (value is Set) {
      return '<dynamic>{${value.map(_literalToCode).join(', ')}}';
    }
    if (value is Map) {
      final String items = value.entries
          .map((MapEntry<dynamic, dynamic> entry) =>
              '${_literalToCode(entry.key)}: ${_literalToCode(entry.value)}')
          .join(', ');
      return '<dynamic, dynamic>{$items}';
    }
    throw InvalidGenerationSourceError(
      'Unsupported defaultValue type: ${value.runtimeType}. Use literal values only.',
    );
  }
}

class _FormatSpec {
  const _FormatSpec({
    required this.kind,
    required this.pattern,
  });

  final String kind;
  final String? pattern;
}
