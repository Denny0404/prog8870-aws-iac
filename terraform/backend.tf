# Local backend (per assignment requirement)
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
