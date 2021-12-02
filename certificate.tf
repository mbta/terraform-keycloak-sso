# certificate generation is optional, only used if var isn't passed
resource "tls_private_key" "keycloak-pk" {
  count     = var.acm_certificate_arn == null ? 1 : 0
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "keycloak-certificate-body" {
  count           = var.acm_certificate_arn == null ? 1 : 0
  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.keycloak-pk.*.private_key_pem

  subject {
    common_name  = var.hostname
    organization = var.organization
  }

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth"
  ]
}

resource "aws_acm_certificate" "keycloak-certificate" {
  count            = var.acm_certificate_arn == null ? 1 : 0
  private_key      = tls_private_key.keycloak-pk.*.private_key_pem
  certificate_body = tls_self_signed_cert.keycloak-certificate-body.*.cert_pem
}
