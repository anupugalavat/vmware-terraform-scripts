##############################################
#Vmware vsphere provider Credentials
##############################################
provider "vsphere" {
  vsphere_server       = var.vcenter_host
  user                 = var.vcenter_user_name
  password             = var.vcenter_password
  allow_unverified_ssl = true
}

# All fields in the vsphere_virtual_disk resource are currently immutable and force a new resource if changed.

#Vmware Vsphere dynatrace opt storage volume
resource "vsphere_virtual_disk" "dynatrace_opt_storage_volume" {
  count      = var.instances
  create_directories = true
  type       = "thin"
  vmdk_path  = "apm-volumes/dynatrace_opt_storage_volume-${count.index}.vmdk"
  datacenter = var.vsphere_datacenter
  datastore  = "/${var.vsphere_datacenter}/datastore/${var.vsphere_datastore[ count.index %  length(var.vsphere_datastore)]}"
  size       = "25"
}

#Vmware Vsphere dynatrace transaction data volume
resource "vsphere_virtual_disk" "dynatrace_transaction_data_volume" {
  count      = var.instances  
  create_directories = true
  type       = "thin"
  size       = var.transaction_data_volume_size
  vmdk_path  = "apm-volumes/dynatrace_transaction_data_volume-${count.index}.vmdk"
  datacenter = var.vsphere_datacenter
  datastore  = "/${var.vsphere_datacenter}/datastore/${var.vsphere_datastore[ count.index %  length(var.vsphere_datastore)]}"
}

#Vmware Vsphere dynatrace long term volume
resource "vsphere_virtual_disk" "dynatrace_long_term_volume" {
  count      = var.instances
  create_directories = true
  type       = "thin"
  size       = var.long_term_volume_size
  vmdk_path  = "apm-volumes/dynatrace_long_term_volume-${count.index}.vmdk"
  datacenter = var.vsphere_datacenter
  datastore  = "/${var.vsphere_datacenter}/datastore/${var.vsphere_datastore[ count.index %  length(var.vsphere_datastore)]}"
}

#Vmware Vsphere dynatrace nfs backup volume
resource "vsphere_virtual_disk" "dynatrace_nfs_backup_volume" {
  count      = 1
  create_directories = true
  type       = "thin"
  size       = var.backup_volume_size
  vmdk_path  = "apm-volumes/dynatrace_nfs_backup_volume.vmdk"
  datacenter = var.vsphere_datacenter
  datastore  = "/${var.vsphere_datacenter}/datastore/${var.vsphere_datastore[ count.index %  length(var.vsphere_datastore)]}"
}

#output all vmdk paths which will be consumed by attaching disk in vsphere_virtual_machine resources in vms.tf
output "dynatrace_opt_storage_volume_vmdk_path" {
  value = join(",", vsphere_virtual_disk.dynatrace_opt_storage_volume.*.id)
}

output "dynatrace_transaction_data_volume_vmdk_path" {
  value = join(",", vsphere_virtual_disk.dynatrace_transaction_data_volume.*.id)
}

output "dynatrace_long_term_volume_vmdk_path" {
  value = join(",", vsphere_virtual_disk.dynatrace_long_term_volume.*.id)
}

output "dynatrace_nfs_backup_volume_vmdk_path" {
  value = join(",", vsphere_virtual_disk.dynatrace_nfs_backup_volume.*.id)
}
