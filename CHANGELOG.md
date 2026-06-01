# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- This `CHANGELOG.md`, following the [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/) format and backfilled to cover every tagged release.
- GitHub Actions CI that runs the test suite across Ruby 2.7 through the current development build, with coverage uploaded to Qlty.
- A rewritten, comprehensive `README.md`, an API stability notice, and a `CLAUDE.md` with notes for contributors.
- `bin/setup` and `bin/console` scripts.
- `homepage_uri`, `source_code_uri`, and `bug_tracker_uri` entries in the gem metadata.

### Changed
- Raised the minimum Ruby version to `>= 2.7.0` (was `>= 2.2.0`). Ruby 2.2 through 2.6 are end of life.
- Bumped the `rake` development dependency to `~> 13.0` (was `~> 10.0`).

### Fixed
- Ruby 3.0+ compatibility in `Micro::Authorization::Model#add_policies`. It no longer relies on `Method#to_proc` auto-splatting the `[key, value]` pair, which raised an `ArgumentError` on Ruby 3.0 and later.

### Removed
- Travis CI configuration (`.travis.yml`), replaced by GitHub Actions.
- `Gemfile.lock` is no longer tracked; it is regenerated per environment.

## [2.3.0] - 2019-08-04
### Changed
- A policy's context must now be a Hash. `current_user` (and its `user` alias) reads `context[:user]` and falls back to `context[:current_user]`; passing a non-Hash context to use directly as the user is no longer supported.
- Clearer `ArgumentError` message from `Micro::Authorization::Model#add_policies` when it is given something other than a Hash.

### Removed
- The deprecation warning on the permission checker's `required_features`. It is now a plain alias of `#features`.

## [2.2.0] - 2019-07-30
### Added
- Multi-role permissions. `Micro::Authorization::Permissions.new` and `Micro::Authorization::Model.build` accept an array of roles and grant the union of their permissions, so a feature is allowed when any role allows it.

### Deprecated
- The permission checker's `required_features`, in favor of `required_context`. This was reverted in 2.3.0, where `#features` became the method name and `required_features` a plain alias.

## [2.1.0] - 2019-07-29
### Added
- `:to_permit` as the context key for permission checks in `Micro::Authorization::Model.build`, with `:permissions` kept as an alias.
- README badges and Travis CI configuration.

## [2.0.0] - 2019-07-26
### Added
- First tagged release of the `Micro::Authorization` architecture: the `Micro::Authorization::Model.build` entry point, the data-driven `Permissions` layer (roles as hashes with `any` / `only` / `except` rules and context matching, including dot-notation segments), and the `Micro::Authorization::Policy` base class for record-level checks that denies undefined predicates by default.
- Each class organized into its own file under `lib/micro/authorization/`, with the test suite running on Minitest.

[Unreleased]: https://github.com/serradura/u-authorization/compare/v2.3.0...HEAD
[2.3.0]: https://github.com/serradura/u-authorization/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/serradura/u-authorization/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/serradura/u-authorization/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/serradura/u-authorization/releases/tag/v2.0.0
