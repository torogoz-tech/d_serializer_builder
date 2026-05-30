# Changelog

All notable changes to this project will be documented in this file.

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
