# Publishing Checklist (d_serializer_builder)

Use this checklist before every `pub.dev` release.

1. Versioning
- Bump `pubspec.yaml` version using semver.
- Add a matching entry in `CHANGELOG.md`.

2. Documentation
- README in English is updated for all generated behavior changes.
- New annotations/options include minimal examples.

3. Quality gates
- `dart pub get`
- `dart analyze`

4. Publishing safety
- Run `dart pub publish --dry-run`.
- Resolve warnings when possible.

5. Git flow
- Commit changes.
- Push to GitHub.
- Publish to pub.dev only after push.
