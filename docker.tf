resource "aws_ecr_repository" "integsoft-images-repository" {
  name                 = "integsoft/keycloak"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
  
  tags = {
     project = "MBTA-Keycloak"
     Name    = "Integsoft Image repository"
  }
}

