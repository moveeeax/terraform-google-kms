# terraform-google-kms

Terraform module that manages a [Google Cloud](https://cloud.google.com/)
Cloud KMS key ring (`google_kms_key_ring`) and a set of crypto keys
(`google_kms_crypto_key`) driven by a map input.

## Usage

```hcl
module "kms" {
  source = "github.com/moveeeax/terraform-google-kms"

  project_id = var.project_id
  name       = "prod-keyring"
  location   = "us-central1"

  keys = {
    # Symmetric encryption key, rotated every 90 days (the default).
    "database" = {
      rotation_period = "7776000s"
    }

    # HSM-backed signing key. Signing keys cannot be rotated automatically.
    "signing" = {
      purpose          = "ASYMMETRIC_SIGN"
      algorithm        = "EC_SIGN_P256_SHA256"
      protection_level = "HSM"
    }
  }
}
```

A runnable example lives in [`examples/basic`](examples/basic).

## Destruction semantics

Cloud KMS destruction is not symmetric with creation, so read this before
running `terraform destroy` against a key ring you care about.

* **Destroying a crypto key destroys key material.** The provider cannot delete
  a `CryptoKey`, so on destroy it schedules *every version* of the key for
  destruction and drops the key from state. Once the
  `destroy_scheduled_duration` window elapses (30 days by default) those
  versions are gone permanently, and so is anything they encrypted. Keys are
  therefore created with `lifecycle { prevent_destroy = true }` by default:
  `terraform destroy`, removing an entry from `keys`, or changing an immutable
  field all fail at plan time instead of putting key material on a countdown.
  Set `prevent_destroy = false` for throwaway environments only.
* **Key rings are never deleted.** GCP has no API to delete a `KeyRing`.
  `terraform destroy` only removes it from state; the ring stays in the project
  forever, and a later apply fails with `AlreadyExists` unless you
  `terraform import` it back.
* **Several key fields are immutable.** `purpose`, `algorithm`,
  `protection_level` and `destroy_scheduled_duration` cannot be changed in
  place. Terraform would have to replace the key, which means destroying it —
  and that is refused while `prevent_destroy` is on. Create a new key and
  re-encrypt instead.

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| google    | >= 5.0   |

Running the test suite (`terraform test`) additionally needs Terraform or
OpenTofu >= 1.7 for provider mocking. The module itself still works on 1.5.

## Inputs

| Name              | Description                                               | Type          | Default | Required |
|-------------------|-----------------------------------------------------------|---------------|---------|:--------:|
| `project_id`      | ID of the project in which to create the key ring.        | `string`      | n/a     |   yes    |
| `name`            | Name of the KMS key ring.                                 | `string`      | n/a     |   yes    |
| `location`        | Location of the key ring.                                 | `string`      | n/a     |   yes    |
| `keys`            | Crypto keys keyed by name (see below).                    | `map(object)` | `{}`    |    no    |
| `prevent_destroy` | Protect the crypto keys from destruction and replacement. | `bool`        | `true`  |    no    |
| `labels`          | Labels applied to the crypto keys.                        | `map(string)` | `{}`    |    no    |

### `keys` attributes

| Name                         | Description                                                                                                                       | Default                                           |
|------------------------------|-----------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------|
| `rotation_period`            | Automatic rotation period, at least `86400s`. Only valid for `ENCRYPT_DECRYPT` and `RAW_ENCRYPT_DECRYPT`.                          | `7776000s` for `ENCRYPT_DECRYPT`, otherwise unset |
| `purpose`                    | Key purpose: `ENCRYPT_DECRYPT`, `RAW_ENCRYPT_DECRYPT`, `ASYMMETRIC_SIGN`, `ASYMMETRIC_DECRYPT`, `MAC` or `KEY_ENCAPSULATION`.      | `ENCRYPT_DECRYPT`                                 |
| `algorithm`                  | Algorithm for versions of the key. Must match `purpose`.                                                                          | `GOOGLE_SYMMETRIC_ENCRYPTION`                     |
| `protection_level`           | `SOFTWARE` or `HSM`.                                                                                                              | `SOFTWARE`                                        |
| `destroy_scheduled_duration` | Time versions spend in `DESTROY_SCHEDULED` before being destroyed, at least `86400s`.                                             | unset (Cloud KMS default: 30 days)                |

`purpose` and `algorithm` are validated against each other, so a mismatch such
as `ASYMMETRIC_SIGN` with `GOOGLE_SYMMETRIC_ENCRYPTION` is rejected during plan
instead of failing part-way through an apply.

## Outputs

| Name             | Description                                       |
|------------------|---------------------------------------------------|
| `key_ring_id`    | Identifier of the key ring.                      |
| `key_ring_name`  | Name of the key ring.                            |
| `crypto_key_ids` | Identifiers of the crypto keys created.          |

## Development

```sh
terraform fmt -recursive
terraform init -backend=false
terraform validate
terraform test
```

The suite in [`tests/`](tests) uses a mocked provider, so it needs no GCP
credentials and no network access.

## License

[MIT](LICENSE)
