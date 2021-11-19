# TODO will be removed
resource "tls_private_key" "keycloak-pk" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "keycloak-certificate-body" {
  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.keycloak-pk.private_key_pem

  subject {
    common_name  = "mbta-login.integsoft.com"
    organization = "Integsoft"
  }

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth"
  ]
}

resource "aws_acm_certificate" "keycloak-certificate" {
  private_key      = tls_private_key.keycloak-pk.private_key_pem
  certificate_body = tls_self_signed_cert.keycloak-certificate-body.cert_pem
}

data "aws_acm_certificate" "mbta" {
  domain   = "mbta-login.integsoft.com"
  statuses = ["ISSUED"]
  most_recent = true

  depends_on = [aws_acm_certificate.keycloak-certificate]
}

