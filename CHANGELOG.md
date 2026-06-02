# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased] - 2026-06-02

### Added
- **Polymorphic union generation**: Builder now detects `@SerializableUnion` annotations and generates `Serializer.registerUnion<T>(...)` calls for each subtype.
  - Automatic discriminator field inclusion in generated JSON
  - Union factory registration for runtime type resolution

## [1.1.4] - 2026-06-01

### Fixed
- Removed redundant casts in generated formatter pipelines to satisfy pub.dev static analysis (`unnecessary_cast`).

## [1.1.3] - 2026-06-01

### Added
- Typed formatter support in codegen for `@Format.customWith(TypeName)`.

### Fixed
- `@Format.date(...)` generation pipeline now preserves correct DateTime/String transformation order.
- Generated serializer files now include lint suppression for naming required by generated APIs.
- Reduced unnecessary cast generation in formatter pipelines.

### Changed
- Builder README updated with typed formatter contract.

## [1.1.2] - 2026-05-30

### Changed
- Release metadata and docs aligned with `d_serializer 1.1.2`.
- Builder release process documentation improved and synchronized.

## [1.1.1] - 2026-05-30

### Changed
- Builder release metadata aligned for `d_serializer 1.1.x` consumption.
- Release process documentation improved with a pre-publish checklist.

## [1.1.0] - 2026-05-30

### Added
- Formatter generation support for `@Format(...)`:
  - `trim`, `uppercase`, `lowercase`
  - `date('yyyy-MM-dd')`, `date('iso8601')`
  - `custom('X')` calling `XFormatToJson` / `XFormatFromJson`
- Build-time validation for formatter compatibility:
  - String formatters only on `String` / `String?`
  - Date formatter only on `DateTime` / `DateTime?`
  - Empty `@Format.custom('')` is rejected

### Fixed
- Registry generation in Flutter/build_runner synthetic input path (`lib/$lib$`).
- `d_serializer_registry.g.dart` generation reliability for `initializeDSerializer()`.

### Changed
- README expanded with formatter behavior, validation rules, and custom formatter contract.

## [1.0.2] - 2026-05-29

### Fixed
- Fixed registry generation in Flutter/build_runner environments where the synthetic input path is `lib/$lib$`.
- `d_serializer_registry.g.dart` is now generated correctly so apps can use `initializeDSerializer()` without manual per-model registration.

## [1.0.1] - 2026-05-29

### Changed
- Improved pub.dev metadata and repository links.
- Upgraded dependency constraints for modern ecosystem compatibility.
- Added package example and expanded public API docs.

## [1.0.0] - 2026-05-29

### Added
- `@Serializable()` model generator builder (`*.g.dart`).
- Global registry builder for `initializeDSerializer()` (`d_serializer_registry.g.dart`).
- Support for `JsonKey` options used by `d_serializer`:
  - `name`, `ignore`, `defaultValue`, `converter`, `useEnumIndex`
  - `requiredKey`, `unknownEnumValue`
- Support for `Serializable` options used by `d_serializer`:
  - `rename`, `discriminator`, `typeField`, `strict`, `naming`
