/// Library entry points for `d_serializer_builder` generators.
library d_serializer_builder;

import 'package:build/build.dart';
import 'package:d_serializer_builder/src/generator.dart';
import 'package:d_serializer_builder/src/registry_builder.dart';
import 'package:source_gen/source_gen.dart';

/// Creates the `*.g.dart` model serializer builder.
Builder buildSerializer(BuilderOptions options) {
  return PartBuilder(
    <Generator>[SerializableGenerator()],
    '.g.dart',
  );
}

/// Creates the global registry builder (`d_serializer_registry.g.dart`).
Builder buildSerializerRegistry(BuilderOptions options) {
  return SerializerRegistryBuilder();
}
