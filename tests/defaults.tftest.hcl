# Requires Terraform >= 1.7 / OpenTofu >= 1.7 for `mock_provider`. The module
# itself still supports >= 1.5; this is a test-only requirement.
#
# Every run is plan-only on purpose: the values asserted on are all known at
# plan time, so the suite needs neither credentials nor any state to clean up.

mock_provider "google" {}

variables {
  project_id = "example-project"
  name       = "test-keyring"
  location   = "us-central1"
}

run "symmetric_key_defaults" {
  command = plan

  variables {
    keys = {
      "app" = {}
    }
  }

  assert {
    condition     = google_kms_crypto_key.this["app"].purpose == "ENCRYPT_DECRYPT"
    error_message = "Default key purpose must be ENCRYPT_DECRYPT."
  }

  assert {
    condition     = google_kms_crypto_key.this["app"].rotation_period == "7776000s"
    error_message = "Symmetric keys must default to 90 day automatic rotation."
  }

  assert {
    condition     = google_kms_crypto_key.this["app"].version_template[0].algorithm == "GOOGLE_SYMMETRIC_ENCRYPTION"
    error_message = "Default algorithm must be GOOGLE_SYMMETRIC_ENCRYPTION."
  }

  assert {
    condition     = google_kms_crypto_key.this["app"].version_template[0].protection_level == "SOFTWARE"
    error_message = "Default protection level must be SOFTWARE."
  }

  assert {
    condition     = length(google_kms_crypto_key.ephemeral) == 0
    error_message = "Keys must be created on the destroy-protected resource by default."
  }
}

# The Cloud KMS API only rotates ENCRYPT_DECRYPT keys automatically; sending a
# rotation_period for any other purpose fails at apply time.
run "asymmetric_key_gets_no_rotation_period" {
  command = plan

  variables {
    keys = {
      "signer" = {
        purpose   = "ASYMMETRIC_SIGN"
        algorithm = "EC_SIGN_P256_SHA256"
      }
    }
  }

  assert {
    condition     = google_kms_crypto_key.this["signer"].rotation_period == null
    error_message = "Non-symmetric keys must not be given a rotation_period."
  }
}

run "raw_symmetric_key_gets_no_default_rotation_period" {
  command = plan

  variables {
    keys = {
      "raw" = {
        purpose   = "RAW_ENCRYPT_DECRYPT"
        algorithm = "AES_256_GCM"
      }
    }
  }

  assert {
    condition     = google_kms_crypto_key.this["raw"].rotation_period == null
    error_message = "RAW_ENCRYPT_DECRYPT keys must not inherit the symmetric rotation default."
  }
}

run "per_key_overrides_are_honoured" {
  command = plan

  variables {
    keys = {
      "hsm" = {
        protection_level           = "HSM"
        rotation_period            = "2592000s"
        destroy_scheduled_duration = "7776000s"
      }
    }
    labels = { env = "test" }
  }

  assert {
    condition     = google_kms_crypto_key.this["hsm"].version_template[0].protection_level == "HSM"
    error_message = "protection_level must be configurable per key."
  }

  assert {
    condition     = google_kms_crypto_key.this["hsm"].rotation_period == "2592000s"
    error_message = "An explicit rotation_period must override the default."
  }

  assert {
    condition     = google_kms_crypto_key.this["hsm"].destroy_scheduled_duration == "7776000s"
    error_message = "destroy_scheduled_duration must be passed through to the key."
  }

  assert {
    condition     = google_kms_crypto_key.this["hsm"].labels["env"] == "test"
    error_message = "Labels must be applied to the crypto keys."
  }
}

run "prevent_destroy_can_be_opted_out" {
  command = plan

  variables {
    prevent_destroy = false
    keys = {
      "scratch" = {}
    }
  }

  assert {
    condition     = length(google_kms_crypto_key.this) == 0
    error_message = "With prevent_destroy = false no key may use the protected resource."
  }

  assert {
    condition     = google_kms_crypto_key.ephemeral["scratch"].rotation_period == "7776000s"
    error_message = "The ephemeral resource must resolve the same key settings as the protected one."
  }
}
