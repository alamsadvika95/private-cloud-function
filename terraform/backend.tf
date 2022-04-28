terraform {
  backend "gcs" {
    bucket = "datalabs-hs"
    prefix = "terraform/state"
  }
}
