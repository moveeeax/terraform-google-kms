locals {
  # Applied to symmetric ENCRYPT_DECRYPT keys when the caller does not set one.
  # 7776000s == 90 days.
  default_rotation_period = "7776000s"

  # Resolve the effective settings for each key once, so that the two crypto key
  # resources below stay identical apart from their destroy behaviour.
  #
  # Automatic rotation is only supported by the Cloud KMS API for keys whose
  # purpose is ENCRYPT_DECRYPT; sending rotation_period for any other purpose
  # fails at apply time. var.keys validation rejects it for the purposes that
  # cannot rotate at all, and it is left unset (rather than defaulted) for
  # RAW_ENCRYPT_DECRYPT.
  keys = {
    for name, key in var.keys : name => {
      purpose                    = key.purpose
      algorithm                  = key.algorithm
      protection_level           = key.protection_level
      destroy_scheduled_duration = key.destroy_scheduled_duration
      rotation_period = (
        key.purpose == "ENCRYPT_DECRYPT"
        ? coalesce(key.rotation_period, local.default_rotation_period)
        : key.rotation_period
      )
    }
  }
}

resource "google_kms_key_ring" "this" {
  project  = var.project_id
  name     = var.name
  location = var.location
}

# Default path: keys are protected from destruction. A `terraform destroy` (or
# any change that would force replacement) fails at plan time instead of
# scheduling every version of the key for destruction, which is irreversible
# once the destroy_scheduled_duration window elapses.
resource "google_kms_crypto_key" "this" {
  for_each = var.prevent_destroy ? local.keys : {}

  name                       = each.key
  key_ring                   = google_kms_key_ring.this.id
  rotation_period            = each.value.rotation_period
  purpose                    = each.value.purpose
  destroy_scheduled_duration = each.value.destroy_scheduled_duration
  labels                     = var.labels

  version_template {
    algorithm        = each.value.algorithm
    protection_level = each.value.protection_level
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Opt-in path for throwaway environments (var.prevent_destroy = false). The
# resource body is identical; only the lifecycle block differs, because
# prevent_destroy cannot be driven by a variable.
resource "google_kms_crypto_key" "ephemeral" {
  for_each = var.prevent_destroy ? {} : local.keys

  name                       = each.key
  key_ring                   = google_kms_key_ring.this.id
  rotation_period            = each.value.rotation_period
  purpose                    = each.value.purpose
  destroy_scheduled_duration = each.value.destroy_scheduled_duration
  labels                     = var.labels

  version_template {
    algorithm        = each.value.algorithm
    protection_level = each.value.protection_level
  }

  lifecycle {
    prevent_destroy = false
  }
}
