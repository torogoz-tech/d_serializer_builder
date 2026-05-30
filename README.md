# d_serializer_builder

`d_serializer_builder` is the code generation package used by `d_serializer`.

It generates:

- `*.g.dart` model serializers (`FromJson`, `toJson`, registration helpers)
- `d_serializer_registry.g.dart` with `initializeDSerializer()`

## Installation

```yaml
dependencies:
  d_serializer: ^1.0.2

dev_dependencies:
  build_runner: ^2.10.3
  d_serializer_builder: ^1.0.2
```

## Usage

### 1) Annotate models

```dart
import 'package:d_serializer/d_serializer.dart';

part 'user.g.dart';

@Serializable()
class User {
  final int id;
  final String name;

  User({required this.id, required this.name});
}
```

### 2) Generate

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 3) Initialize once

```dart
import 'd_serializer_registry.g.dart';

void main() {
  initializeDSerializer();
}
```

### 4) Use static API

```dart
final json = Serializer.toJson<User>(user);
final restored = Serializer.fromJson<User>(json);
```

## Formatter Support (`@Format`)

The builder supports formatter pipelines per field:

- `@Format.trim()`
- `@Format.uppercase()`
- `@Format.lowercase()`
- `@Format.date('yyyy-MM-dd')`
- `@Format.date('iso8601')`
- `@Format.custom('X')`

Build-time validation includes:

- String formatters require `String`/`String?` fields.
- Date formatter requires `DateTime`/`DateTime?` fields.
- Empty custom formatter names fail generation.

For `@Format.custom('X')`, the model library must provide:

- `XFormatToJson(dynamic value)`
- `XFormatFromJson(dynamic value)`

## What Is Generated

For a model `User`, generation includes:

- `UserFromJson(Map<String, dynamic>)`
- `extension UserSerializer on User { Map<String, dynamic> toJson() }`
- `registerUserSerializer()`

And global file:

- `initializeDSerializer()` that registers all annotated models under `lib/`

## Notes

- This package is intended to be used through `build_runner`.
- Generated files are source-of-truth outputs and should not be manually edited.

## License

MIT
