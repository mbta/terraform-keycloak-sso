resource "aws_ecr_repository" "keycloak-image-repository" {
  count = var.ecr_keycloak_image_url == null ? 1 : 0

  name                 = "keycloak"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    project = "MBTA-Keycloak"
    Name    = "Integsoft Image repository"
  }
}

