/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

###############################################################################
#                                  VPCs                                       #
###############################################################################
locals {
  psc_name = replace(var.name, "-", "")
}

module "firewall-onprem" {
  source     = "../../../modules/net-vpc-firewall"
  project_id = var.project_id
  network    = module.vpc-onprem.name
}

module "vpc-hub" {
  source     = "../../../modules/net-vpc"
  project_id = var.project_id
  name       = "${var.name}-hub"
  subnets = [
    {
      ip_cidr_range      = var.ip_ranges.hub
      name               = "${var.name}-hub"
      region             = var.region
      secondary_ip_range = {}
    }
  ]
}

# ###############################################################################
# #                                  VMs                                        #
# ###############################################################################

module "test-vm" {
  source        = "../../../modules/compute-vm"
  project_id    = var.project_id
  zone          = "${var.region}-b"
  name          = "${var.name}-test"
  instance_type = "e2-micro"
  boot_disk = {
    image = "debian-cloud/debian-9"
    type  = "pd-balanced"
    size  = 10
  }
  network_interfaces = [{
    addresses  = null
    nat        = false
    network    = module.vpc-hub.self_link
    subnetwork = module.vpc-hub.subnet_self_links["${var.region}/${var.name}-onprem"]
  }]
  tags = ["ssh"]
}

# ###############################################################################
# #                              Cloud Function                                 #
# ###############################################################################

module "function-hello" {
  source           = "../../../modules/cloud-function"
  project_id       = var.project_id
  name             = var.name
  bucket_name      = "${var.name}-tf-cf-deploy"
  ingress_settings = "ALLOW_INTERNAL_ONLY"
  bundle_config = {
    source_dir  = "${path.module}/assets"
    output_path = "bundle.zip"
    excludes    = null
  }
  bucket_config = {
    location             = var.region
    lifecycle_delete_age = null
  }
  iam = {
    "roles/cloudfunctions.invoker" = ["allUsers"]
  }
}

# ###############################################################################
# #                                  DNS                                        #
# ###############################################################################

module "private-dns-onprem" {
  source          = "../../../modules/dns"
  project_id      = var.project_id
  type            = "private"
  name            = var.name
  domain          = "${var.region}-${var.project_id}.cloudfunctions.net."
  client_networks = [module.vpc-onprem.self_link]
  recordsets = {
    "A " = { ttl = 300, records = [module.addresses.psc_addresses[local.psc_name].address] }
  }
}

# ###############################################################################
# #                                  PSCs                                       #
# ###############################################################################

module "addresses" {
  source     = "../../../modules/net-address"
  project_id = var.project_id
  psc_addresses = {
    (local.psc_name) = {
      address = var.psc_endpoint
      network = module.vpc-hub.self_link
    }
  }
}

resource "google_compute_global_forwarding_rule" "psc-endpoint" {
  provider              = google-beta
  project               = var.project_id
  name                  = local.psc_name
  network               = module.vpc-hub.self_link
  ip_address            = module.addresses.psc_addresses[local.psc_name].self_link
  target                = "vpc-sc"
  load_balancing_scheme = ""
}
