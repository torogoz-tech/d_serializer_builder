# Changelog

All notable changes to this project will be documented in this file.

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
