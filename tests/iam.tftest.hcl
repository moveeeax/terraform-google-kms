# Per-key usage grants. Plan-only, like the rest of the suite.

mock_provider "google" {}

variables {
  project_id = "example-project"
  name       = "test-keyring"
  location   = "us-central1"
}

run "no_grants_by_default" {
  command = plan

  variables {
    keys = {
      "app" = {}
    }
  }

  assert {
    condition     = length(google_kms_crypto_key_iam_member.this) == 0
    error_message = "A key with no members listed must not get any IAM grants."
  }
}

run "no_keys_no_grants" {
  command = plan

  assert {
    condition     = length(google_kms_crypto_key_iam_member.this) == 0
    error_message = "An empty key map must plan cleanly with no IAM grants."
  }
}

run "grants_each_role_on_its_own_key" {
  command = plan

  variables {
    keys = {
      "gcs" = {
        encrypter_decrypters = ["serviceAccount:service-123@gs-project-accounts.iam.gserviceaccount.com"]
      }
      "backup" = {
        encrypters = ["serviceAccount:writer@example-project.iam.gserviceaccount.com"]
        decrypters = ["group:restore@example.com"]
      }
    }
  }

  assert {
    condition     = length(google_kms_crypto_key_iam_member.this) == 3
    error_message = "Each listed member must get exactly one grant per role."
  }

  assert {
    condition     = google_kms_crypto_key_iam_member.this["gcs/roles/cloudkms.cryptoKeyEncrypterDecrypter/serviceAccount:service-123@gs-project-accounts.iam.gserviceaccount.com"].role == "roles/cloudkms.cryptoKeyEncrypterDecrypter"
    error_message = "encrypter_decrypters must map to roles/cloudkms.cryptoKeyEncrypterDecrypter."
  }

  assert {
    condition     = google_kms_crypto_key_iam_member.this["backup/roles/cloudkms.cryptoKeyEncrypter/serviceAccount:writer@example-project.iam.gserviceaccount.com"].member == "serviceAccount:writer@example-project.iam.gserviceaccount.com"
    error_message = "encrypters must map to roles/cloudkms.cryptoKeyEncrypter."
  }

  assert {
    condition     = google_kms_crypto_key_iam_member.this["backup/roles/cloudkms.cryptoKeyDecrypter/group:restore@example.com"].member == "group:restore@example.com"
    error_message = "decrypters must map to roles/cloudkms.cryptoKeyDecrypter."
  }

  assert {
    condition = alltrue([
      for g in google_kms_crypto_key_iam_member.this : contains([
        "roles/cloudkms.cryptoKeyEncrypter",
        "roles/cloudkms.cryptoKeyDecrypter",
        "roles/cloudkms.cryptoKeyEncrypterDecrypter",
      ], g.role)
    ])
    error_message = "The module must only ever grant key usage roles, never administration."
  }
}

run "duplicate_members_are_granted_once" {
  command = plan

  variables {
    keys = {
      "app" = {
        encrypters = ["group:app@example.com", "group:app@example.com"]
      }
    }
  }

  assert {
    condition     = length(google_kms_crypto_key_iam_member.this) == 1
    error_message = "A member listed twice under the same role must produce a single grant."
  }
}

run "rejects_member_without_type_prefix" {
  command = plan

  variables {
    keys = {
      "app" = { encrypters = ["alice@example.com"] }
    }
  }

  expect_failures = [var.keys]
}

run "rejects_public_members" {
  command = plan

  variables {
    keys = {
      "app" = { decrypters = ["allUsers"] }
    }
  }

  expect_failures = [var.keys]
}

run "grants_follow_unprotected_keys" {
  command = plan

  variables {
    prevent_destroy = false
    keys = {
      "scratch" = { encrypter_decrypters = ["user:alice@example.com"] }
    }
  }

  assert {
    condition     = length(google_kms_crypto_key_iam_member.this) == 1
    error_message = "Grants must also be created for keys on the unprotected resource."
  }
}
