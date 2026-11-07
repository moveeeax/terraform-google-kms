# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.2.0] - 2026-11-07

### Added

- Per-key usage grants: `encrypters`, `decrypters` and `encrypter_decrypters`
  attributes on `keys` create `google_kms_crypto_key_iam_member` grants of
  `roles/cloudkms.cryptoKeyEncrypter`, `roles/cloudkms.cryptoKeyDecrypter` and
  `roles/cloudkms.cryptoKeyEncrypterDecrypter` on that key only. Roles are fixed
  in the module, so it cannot grant key administration. Members must carry a
  type prefix, which also rejects `allUsers` and `allAuthenticatedUsers`.

### Changed

- CI: bump actions to their current majors, pin tool versions, and restrict the
  workflow token to `contents: read`.
- CI: add Dependabot for GitHub Actions and the Terraform provider.
- Docs: pin the README usage `source` to a release tag; fix the LICENSE year.

## [1.0.0]

Initial release (`v0.1.0` points at the same commit).

[Unreleased]: https://github.com/moveeeax/terraform-google-kms/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/moveeeax/terraform-google-kms/compare/v1.1.0...v1.2.0
[1.0.0]: https://github.com/moveeeax/terraform-google-kms/releases/tag/v1.0.0
