# d_serializer_builder

`d_serializer_builder` is the official code generation package for [`d_serializer`](https://github.com/torogoz-tech/d_serializer).

It generates:
- `*.g.dart` - Model serializers (`FromJson`, `toJson`, registration helpers)
- `d_serializer_registry.g.dart` - Global registry with `initializeDSerializer()`

---

## Table of Contents

1. [Overview](#overview)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [What Gets Generated](#what-gets-generated)
5. [Annotation Support](#annotation-support)
   - [@Serializable](#serializable)
   - [@JsonKey](#jsonkey)
   - [@Format](#format)
   - [@SerializableUnion](#serializableunion)
6. [UnknownKeyPolicy Generation](#unknownkeypolicy-generation)
7. [Build Configuration](#build-configuration)
8. [Generated Code Examples](#generated-code-examples)
9. [Build-Time Validation](#build-time-validation)
10. [Troubleshooting](#troubleshooting)
11. [License](#license)

---

## Overview

The builder analyzes your annotated Dart classes and generates serialization code:

- Eliminates manual `toMap()`/`fromMap()` boilerplate
- Supports complex type hierarchies (polymorphism, unions)
- Provides formatters, converters, and validation
- Generates type-safe, performant code

### Generated Files

| File | Purpose |
|------|---------|
| `model.g.dart` | Serializer for specific model |
| `d_serializer_registry.g.dart` | Global registry for all models |

---

## Installation

```yaml
dependencies:
  d_serializer: ^1.2.0

dev_dependencies:
  build_runner: ^2.10.3
  d_serializer_builder: ^1.2.0
```

Run:
```bash
dart pub get
```

---

## Quick Start

### 1. Annotate your models

```dart
import 'package:d_serializer/d_serializer.dart';

part 'user.g.dart';

@Serializable()
class User {
  @JsonKey(requiredKey: true)
  final int id;

  @JsonKey(requiredKey: true)
  final String name;

  User({required this.id, required this.name});
}
```

### 2. Run code generation

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 3. Initialize the registry

```dart
import 'd_serializer_registry.g.dart';

void main() {
  initializeDSerializer();
  
  // Ready to serialize/deserialize
  final user = User(id: 1, name: 'Abner');
  final json = Serializer.toJson<User>(user);
}
```

---

## What Gets Generated

For a model like `User`:

```dart
// user.g.dart content:

User UserFromJson(Map<String, dynamic> json) {
  return User(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String,
  );
}

Map<String, dynamic> UserToJson(User value) {
  return value.toJson();
}

void registerUserSerializer() {
  Serializer.register<User>(
    fromJson: UserFromJson,
    toJson: UserToJson,
  );
}

extension UserSerializer on User {
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
    };
  }
}
```

The registry file (`d_serializer_registry.g.dart`) collects all registered models:

```dart
void initializeDSerializer() {
  registerUserSerializer();
  registerProductSerializer();
  registerOrderSerializer();
  // ... all annotated models
}
```

---

## Annotation Support

### @Serializable

Class-level options with generation behavior:

| Parameter | Generated Code |
|-----------|----------------|
| `rename` | Used as discriminator fallback |
| `discriminator` | Sets type discriminator value in `toJson` |
| `typeField` | Adds discriminator field to JSON |
| `unknownKeyPolicy` | Generates key validation logic |
| `naming` | Converts field names (`snake_case`) |

**Example:**

```dart
@Serializable(
  naming: JsonNaming.snakeCase,
  unknownKeyPolicy: UnknownKeyPolicy.strict,
  typeField: 'kind',
  discriminator: 'user_profile',
)
class UserProfile {
  final int id;
  final String fullName;
  
  UserProfile({required this.id, required this.fullName});
}
```

Generates:

```dart
// Adds discriminator field
Map<String, dynamic> toJson() {
  return <String, dynamic>{
    'kind': 'user_profile',
    'id': id,
    'full_name': fullName,  // snake_case
  };
}

// Validates unknown keys
UserProfile UserProfileFromJson(Map<String, dynamic> json) {
  const Set<String> _allowedKeys = <String>{'kind', 'id', 'full_name'};
  for (final String key in json.keys) {
    if (!_allowedKeys.contains(key)) {
      throw ArgumentError('Unknown field for UserProfile: $key');
    }
  }
  // ... rest of generation
}
```

### @JsonKey

Field-level customizations:

| Parameter | Generated Code |
|-----------|----------------|
| `name` | Uses custom key name |
| `ignore` | Skips field in generation |
| `defaultValue` | Uses default when key is null/missing |
| `converter` | Calls `XToJson`/`XFromJson` |
| `useEnumIndex` | Serializes enum by index |
| `requiredKey` | Adds null check guard |
| `unknownEnumValue` | Fallback for unknown enum values |

**Examples:**

```dart
@Serializable()
class Product {
  @JsonKey(name: 'product_id')  // Custom key
  final int id;
  
  @JsonKey(ignore: true)  // Ignored
  final String internalSku;
  
  @JsonKey(defaultValue: 'Default')  // Default value
  final String category;
  
  @JsonKey(converter: 'Money')  // Custom converter
  final Money price;
  
  @JsonKey(requiredKey: true)  // Required
  final String sku;
  
  @JsonKey(useEnumIndex: true)  // By index
  final ProductStatus status;
  
  @JsonKey(unknownEnumValue: 'UNKNOWN')  // Fallback
  final ProductType type;
}
```

### @Format

Formatters generate transformation code:

| Formatter | Generated Expression |
|-----------|---------------------|
| `@Format.trim()` | `(value as String).trim()` |
| `@Format.uppercase()` | `(value as String).toUpperCase()` |
| `@Format.lowercase()` | `(value as String).toLowerCase()` |
| `@Format.date('yyyy-MM-dd')` | `Serializer.formatDate(value, 'yyyy-MM-dd')` |
| `@Format.date('iso8601')` | `value.toIso8601String()` |
| `@Format.custom('X')` | `XFormatToJson(value)` |
| `@Format.customWith(T)` | `TFormatToJson(value)` |

**Pipeline example:**

```dart
@Serializable()
class Article {
  @Format.trim()
  @Format.uppercase()
  final String code;
  
  // Generates: (code.trim().toUpperCase())
}
```

**Custom formatter requirements:**

For `@Format.custom('TitleCase')`:
```dart
dynamic TitleCaseFormatToJson(dynamic value) => ...;
dynamic TitleCaseFormatFromJson(dynamic value) => ...;
```

For `@Format.customWith(TitleCase)`:
```dart
class TitleCase { const TitleCase._(); }
String TitleCaseFormatToJson(dynamic value) => ...;
String TitleCaseFormatFromJson(dynamic value) => ...;
```

### @SerializableUnion

Generates polymorphic union registration:

```dart
@SerializableUnion(typeField: 'type')
sealed class PaymentMethod {}

@Serializable(discriminator: 'card')
class CardPayment extends PaymentMethod {
  final String last4;
  CardPayment({required this.last4});
}

@Serializable(discriminator: 'paypal')
class PaypalPayment extends PaymentMethod {
  final String email;
  PaypalPayment({required this.email});
}
```

Generates registration:

```dart
void registerPaymentMethodSerializer() {
  Serializer.register<CardPayment>(...);
  Serializer.register<PaypalPayment>(...);
  
  // Union registration
  Serializer.registerUnion<PaymentMethod>(
    typeField: 'type',
    discriminator: 'card',
    fromJson: CardPaymentFromJson,
  );
  Serializer.registerUnion<PaymentMethod>(
    typeField: 'type',
    discriminator: 'paypal',
    fromJson: PaypalPaymentFromJson,
  );
}
```

---

## UnknownKeyPolicy Generation

The builder generates different code based on the policy:

### `UnknownKeyPolicy.ignore` (default)

```dart
// No validation code generated
// Unknown keys are simply ignored
```

### `UnknownKeyPolicy.strict`

```dart
User UserFromJson(Map<String, dynamic> json) {
  const Set<String> _allowedKeys = <String>{'id', 'name'};
  for (final String key in json.keys) {
    if (!_allowedKeys.contains(key)) {
      throw ArgumentError('Unknown field for User: $key');
    }
  }
  return User(...);
}
```

### `UnknownKeyPolicy.capture`

```dart
// User must have extra field
@Serializable(unknownKeyPolicy: UnknownKeyPolicy.capture)
class Model {
  final int id;
  final Map<String, dynamic> extra;  // Captured unknown keys
}
```

**Migration from `strict: true`:**

```dart
// Old (still works)
@Serializable(strict: true)

// New (recommended)
@Serializable(unknownKeyPolicy: UnknownKeyPolicy.strict)
```

---

## Build Configuration

### build.yaml

Optional configuration file:

```yaml
targets:
  $default:
    builders:
      d_serializer_builder:
        enabled: true
        generate_for:
          - lib/**/*.dart
```

### CLI Options

**Build (one-time):**
```bash
dart run build_runner build --delete-conflicting-outputs
```

**Watch (development):**
```bash
dart run build_runner watch --delete-conflicting-outputs
```

**Clean and rebuild:**
```bash
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

---

## Generated Code Examples

### Simple Model

**Source:**
```dart
@Serializable()
class User {
  final int id;
  final String name;
  
  User({required this.id, required this.name});
}
```

**Generated:**
```dart
User UserFromJson(Map<String, dynamic> json) {
  return User(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String,
  );
}

extension UserSerializer on User {
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
    };
  }
}
```

### With Formatters

**Source:**
```dart
@Serializable()
class Post {
  @JsonKey(requiredKey: true)
  @Format.trim()
  @Format.uppercase()
  final String title;
  
  @Format.date('yyyy-MM-dd')
  final DateTime createdAt;
  
  Post({required this.title, required this.createdAt});
}
```

**Generated:**
```dart
Post PostFromJson(Map<String, dynamic> json) {
  if (!json.containsKey('title') || json['title'] == null) {
    throw ArgumentError('Missing required field Post.title (title)');
  }
  return Post(
    title: (json['title'] as String).trim().toUpperCase(),
    createdAt: Serializer.parseDate(json['createdAt'] as String, 'yyyy-MM-dd'),
  );
}

extension PostSerializer on Post {
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title.trim().toUpperCase(),
      'createdAt': Serializer.formatDate(createdAt, 'yyyy-MM-dd'),
    };
  }
}
```

### Polymorphic Union

**Source:**
```dart
@SerializableUnion(typeField: 'type')
sealed class Event {}

@Serializable(discriminator: 'click')
class ClickEvent extends Event {
  final String elementId;
  ClickEvent({required this.elementId});
}

@Serializable(discriminator: 'scroll')
class ScrollEvent extends Event {
  final int pixels;
  ScrollEvent({required this.pixels});
}
```

**Generated registration:**
```dart
void registerEventSerializer() {
  Serializer.register<ClickEvent>(
    fromJson: ClickEventFromJson,
    toJson: (v) => v.toJson(),
  );
  Serializer.register<ScrollEvent>(
    fromJson: ScrollEventFromJson,
    toJson: (v) => v.toJson(),
  );
  
  // Union registrations
  Serializer.registerUnion<Event>(
    typeField: 'type',
    discriminator: 'click',
    fromJson: ClickEventFromJson,
  );
  Serializer.registerUnion<Event>(
    typeField: 'type',
    discriminator: 'scroll',
    fromJson: ScrollEventFromJson,
  );
}
```

---

## Build-Time Validation

The builder performs strict type checking at build time:

| Validation | Error |
|-----------|-------|
| `@Format.trim/uppercase/lowercase` on non-String | "only String/String? fields are supported" |
| `@Format.date` on non-DateTime | "only DateTime/DateTime? fields are supported" |
| `@Format.date` without pattern | "pattern is required" |
| `@Format.custom('')` empty name | "formatter name cannot be empty" |
| `@Format.customWith` invalid type | "requires a valid type literal" |

Example error:
```
[d_serializer_builder] Invalid @Format.uppercase on User.name: only String/String? fields are supported.
```

---

## Troubleshooting

### Code not regenerating

```bash
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

### Type not registered error

Ensure `initializeDSerializer()` is called before use.

### Formatter function not found

Check that `XFormatToJson`/`XFormatFromJson` are top-level functions visible in the model library scope.

### Build fails silently

Run with verbose output:
```bash
dart run build_runner build --verbose
```

---

## Integration Examples

### With Flutter

```dart
// lib/models/user.dart
import 'package:d_serializer/d_serializer.dart';

part 'user.g.dart';

@Serializable()
class User {
  final int id;
  final String name;
  
  User({required this.id, required this.name});
}
```

```dart
// lib/main.dart
import 'd_serializer_registry.g.dart';
import 'models/user.dart';

void main() {
  initializeDSerializer();
  runApp(MyApp());
}
```

### With HTTP

```dart
import 'package:http/http.dart' as http;
import 'package:d_serializer/d_serializer.dart';
import 'models/user.dart';

Future<User> fetchUser(int id) async {
  final response = await http.get(Uri.parse('/api/users/$id'));
  return Serializer.fromJson<User>(response.body);
}

Future<void> saveUser(User user) async {
  await http.post(
    Uri.parse('/api/users'),
    headers: {'Content-Type': 'application/json'},
    body: Serializer.toJson<User>(user),
  );
}
```

### With Dio

```dart
import 'package:dio/dio.dart';
import 'package:d_serializer/d_serializer.dart';
import 'models/user.dart';

final dio = Dio();

// Response conversion
final response = await dio.get('/api/users/1');
final user = Serializer.fromJson<User>(response.data);

// Request conversion
final user = User(id: 1, name: 'Abner');
await dio.post('/api/users', data: Serializer.toJson<User>(user));
```

---

## License

MIT

---

## Related

- [`d_serializer`](https://pub.dev/packages/d_serializer) - The serialization API
- [GitHub](https://github.com/torogoz-tech/d_serializer_builder) - Source code
- [Issues](https://github.com/torogoz-tech/d_serializer_builder/issues) - Bug reports