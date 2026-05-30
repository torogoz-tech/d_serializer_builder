import 'dart:async';

import 'package:build/build.dart';
import 'package:glob/glob.dart';

class SerializerRegistryBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions =>
      <String, List<String>>{r'$lib$': <String>['d_serializer_registry.g.dart']};

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    final String inputPath = buildStep.inputId.path;
    if (inputPath != r'$lib$' && inputPath != r'lib/$lib$') {
      return;
    }

    final List<_ClassRef> classes = <_ClassRef>[];

    await for (final AssetId asset in buildStep.findAssets(Glob('lib/**.dart'))) {
      if (asset.path.endsWith('.g.dart') || asset.path.endsWith('d_serializer_registry.g.dart')) {
        continue;
      }

      final String source = await buildStep.readAsString(asset);
      final Iterable<RegExpMatch> matches = RegExp(
        r'@Serializable(?:\s*\([^)]*\))?\s*class\s+([A-Za-z_][A-Za-z0-9_]*)',
        multiLine: true,
      ).allMatches(source);

      for (final RegExpMatch match in matches) {
        final String? className = match.group(1);
        if (className == null) {
          continue;
        }
        classes.add(_ClassRef(asset.path, className));
      }
    }

    final StringBuffer content = StringBuffer()
      ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
      ..writeln()
      ..writeln("import 'package:d_serializer/d_serializer.dart';");

    for (int i = 0; i < classes.length; i++) {
      content.writeln("import '${_importPath(classes[i].filePath)}' as _m$i;");
    }

    content
      ..writeln()
      ..writeln('bool _dSerializerInitialized = false;')
      ..writeln()
      ..writeln('void initializeDSerializer() {')
      ..writeln('  if (_dSerializerInitialized) {')
      ..writeln('    return;')
      ..writeln('  }')
      ..writeln('  _dSerializerInitialized = true;');

    for (int i = 0; i < classes.length; i++) {
      content.writeln('  _m$i.register${classes[i].className}Serializer();');
    }

    content.writeln('}');

    final AssetId output = AssetId(buildStep.inputId.package, 'lib/d_serializer_registry.g.dart');
    await buildStep.writeAsString(output, content.toString());
  }

  String _importPath(String path) {
    if (path.startsWith('lib/')) {
      return path.substring(4);
    }
    return path;
  }
}

class _ClassRef {
  const _ClassRef(this.filePath, this.className);

  final String filePath;
  final String className;
}
