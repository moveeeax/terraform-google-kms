output "key_ring_id" {
  description = "Identifier of the key ring."
  value       = google_kms_key_ring.this.id
}

output "key_ring_name" {
  description = "Name of the key ring."
  value       = google_kms_key_ring.this.name
}

output "crypto_key_ids" {
  description = "Identifiers of the crypto keys created in the key ring."
  value       = { for k, key in google_kms_crypto_key.this : k => key.id }
}
