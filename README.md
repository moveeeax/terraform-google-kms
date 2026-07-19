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
    "database" = {
      rotation_period = "7776000s"
    }
  }
}
```

A runnable example lives in [`examples/basic`](examples/basic).

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| google    | >= 5.0   |

## Inputs

| Name         | Description                                              | Type          | Default | Required |
|--------------|----------------------------------------------------------|---------------|---------|:--------:|
| `project_id` | ID of the project in which to create the key ring.       | `string`      | n/a     |   yes    |
| `name`       | Name of the KMS key ring.                                | `string`      | n/a     |   yes    |
| `location`   | Location of the key ring.                                | `string`      | n/a     |   yes    |
| `keys`       | Crypto keys keyed by name (rotation_period, purpose, algorithm). | `map(object)` | `{}` |    no    |
| `labels`     | Labels applied to the crypto keys.                       | `map(string)` | `{}`    |    no    |

## Outputs

| Name             | Description                                       |
|------------------|---------------------------------------------------|
| `key_ring_id`    | Identifier of the key ring.                      |
| `key_ring_name`  | Name of the key ring.                            |
| `crypto_key_ids` | Identifiers of the crypto keys created.          |

## License

[MIT](LICENSE)
