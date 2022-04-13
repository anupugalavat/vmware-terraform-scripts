###############################################
#NSX-T provider Credentials
###############################################
provider "nsxt" {
  host                 = var.nsxt_host
  username             = var.nsxt_user_name
  password             = var.nsxt_password
  allow_unverified_ssl = true
}

#public ip allocation from pool for dynatrace instances
resource "nsxt_policy_ip_address_allocation" "dynatrace_public_ip" {
  count        = var.instances
  display_name = "dynatrace-public-ip-${count.index}"
  description  = "Public ip address allocated from pool for dynatrace instances"
  pool_path    = var.nsxt_policy_ip_pool_path
}

#public ip allocation from pool for cluster active gate instances
resource "nsxt_policy_ip_address_allocation" "cluster_active_gate_ips" {
  count        = var.cluster_active_gate_instances
  display_name = "dynatrace-cluster-active-gate-ip-${count.index}"
  description  = "Public ip address for allocated from pool for dynatrace cluster active gates instances"
  pool_path    = var.nsxt_policy_ip_pool_path
}

#public ip allocation from pool for cluster synthetic active gate instances
resource "nsxt_policy_ip_address_allocation" "cluster_synthetic_active_gate_ips" {
  count        = var.cluster_synthetic_active_gate_instances
  display_name = "dynatrace-cluster-synthetic-active-gate-ip-${count.index}"
  description  = "Public ip address for allocated from pool for dynatrace cluster active gates instances"
  pool_path    = var.nsxt_policy_ip_pool_path
}

#output list of public allocation ips from pool which will be consumed for natting with private ip of vsphere_virtual_machine in vms.tf
output "public_ips" {
  value = split(",", join(",", nsxt_policy_ip_address_allocation.dynatrace_public_ip.*.allocation_ip))
}

output "cluster_active_gate_public_ips" {
  value = split(",", join(",", nsxt_policy_ip_address_allocation.cluster_active_gate_ips.*.allocation_ip))
}

output "cluster_synthetic_active_gate_public_ips" {
  value = split(",", join(",", nsxt_policy_ip_address_allocation.cluster_synthetic_active_gate_ips.*.allocation_ip))
}