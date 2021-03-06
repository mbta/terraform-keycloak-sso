# certificate generation is optional, only used if var isn't passed
resource "tls_private_key" "keycloak-pk" {
  # only create this resource if acm_certificate_arn is null
  count = var.acm_certificate_arn == null ? 1 : 0

  algorithm = "RSA"
}

resource "tls_self_signed_cert" "keycloak-certificate-body" {
  # only create this resource if acm_certificate_arn is null
  count = var.acm_certificate_arn == null ? 1 : 0

  private_key_pem = join("", tls_private_key.keycloak-pk.*.private_key_pem)

  subject {
    common_name  = var.acm_hostname
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
  # only create this resource if acm_certificate_arn is null
  count = var.acm_certificate_arn == null ? 1 : 0

  private_key      = tls_private_key.keycloak-pk.*.private_key_pem
  certificate_body = tls_self_signed_cert.keycloak-certificate-body.*.cert_pem

  tags = var.tags
}
