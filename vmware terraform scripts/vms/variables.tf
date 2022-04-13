#
# Vcenter provider information
#
variable "vcenter_host" {
  type        = string
  description = "vcenter sever ip"
}

variable "vcenter_user_name" {
  type        = string
  description = "vcenter user name"
}

variable "vcenter_password" {
  type        = string
  description = "vcenter password"
}

#
# NSX-T provider information
#
variable "nsxt_host" {
  type        = string
  description = "nsxt Workload Domain NSX-T LB ip"
}

variable "nsxt_user_name" {
  type        = string
  description = "nsxt host user name"
}

variable "nsxt_password" {
  type        = string
  description = "nsxt host password"
}

#
# VMware Vsphere landscape details
#
variable "vsphere_datacenter" {
  type        = string
  description = "vsphere datacenter name"
}

variable "vsphere_datastore" {
  type        = list
  description = "list of datastores for instance"
}

variable "vsphere_distributed_virtual_switch" {
  type        = list(string)
  description = "vsphere distributed virtual switch name"
}

#
# VMware Vsphere content library details
#
variable "vsphere_content_library" {
  type        = string
  description = "vsphere content library name to create"
}

variable "vsphere_content_library_item_name" {
  type        = string
  description = "name of the ubuntu ova template to create"
}

#
# landscape details
#

variable "landscape_name" {
  type        = string
  description = "landscape name used as general prefix for element names"
}

variable "availability_zones" {
  type        = list(string)
  description = "vsphere availability zones"
}

variable "guest_id" {
  type        = string
  description = "guest id of os image of the ova template used for dynatrace instance"
}

#
# Dynatrace instance config details
#
variable "instances" {
  type        = number
  description = "number of dynatrace instances"
}

variable "root_volume_size" {  
  type        = number
  description = "os disk size in GB for dynatrace instance"
}

variable "public_ips"{
  type        = list(string)
  description = "Comma-separated list of public IPs to attach to dynatrace VMs"
}

#
# Dynatrace cluster active gate instance config details
#
variable "cluster_active_gate_instances" {
  type        = number
  description = "number of dynatrace cluster active gate instances"
}
variable "cluster_active_gate_public_ips" {
  type        = list(string)
  description = "Comma-separated list of public IPs to attach to dynatrace cluster active gate VMs"
}

#
# Dynatrace cluster synthetic active gate instance config details
#
variable "cluster_synthetic_active_gate_instances" {
  type        = number
  description = "number of dynatrace cluster synthetic active gate instances"
}

variable "cluster_synthetic_active_gate_public_ips" {
  type        = list(string)
  description = "Comma-separated list of public IPs to attach to dynatrace cluster synthetic active gate VMs"
}

#
# NSXT network segment
#
variable "nsxt_policy_network_segment" {
  type        = string
  description = "policy resource - network segment name"
}

#
# NSXT tier1 gateway
#
variable "nsxt_policy_tier1_gateway" {
  type        = string
  description = "policy resource - tier1-gateway name"
}

#
# public ip pool path
#
variable "nsxt_policy_ip_pool_path" {
  type        = string
  description = "nsxt path of ip pool which contains public ips"
}

#
# Disks vmdk path - outputs of disks.tf file
#
variable "dynatrace_opt_storage_volume_vmdk_path" {
  type        = string
  description = "Comma-separated list of volumes for dynatrace opt storage"
}

variable "dynatrace_transaction_data_volume_vmdk_path" {
  type        = string
  description = "Comma-separated list of volumes for dynatrace transaction data"
}

variable "dynatrace_long_term_volume_vmdk_path" {
  type        = string
  description = "Comma-separated list of volumes for dynatrace long term data"
}

variable "dynatrace_nfs_backup_volume_vmdk_path" {
  type        = string
  description = "Comma-separated list of volumes for nfs backups"
}

#
# Volumes mounts
#
variable "dynatrace_opt_volume_mount" {
  description = "mount point for opt"
}

variable "dynatrace_raw_data_volume_mount" {
  description = "mount point for raw data"
}

variable "dynatrace_longterm_data_volume_mount" {
  description = "mount point for long-term data"
}

variable "dynatrace_backup_volume_mount" {
  description = "mount point for backups"
}

variable "dynatrace_backup_nfs_mount" {
  description = "mount point for nfs backups"
}

#
# firewall details
#
variable "ui_allowlist" {
  type        = list(string)
  description = "a set of CIDRs that are allowed to access dynatrace VMs on port 443"
}

variable "ui_allowlist_enabled" {
  type        = string
  description = "set to true/false to enable/disable restricted access through a whitelist"
}

variable "agent_allowlist" {
  type        = list(string)
  description = "a set of CIDRs that are allowed to access dynatrace VMs on port 8443"
}

variable "agent_allowlist_enabled" {
  type        = string
  description = "set to true/false to enable/disable restricted access through a whitelist"
}

variable "ssh_allowlist" {
  type        = list(string)
  description = "a set of CIDRs that are allowed to access dynatrace VMs on port 22"
}

variable "ssh_allowlist_enabled" {
  type        = string
  description = "set to true/false to enable/disable restricted access through a whitelist"
}

# User for OS access
variable "os_user" {
  type        = string
  description = "user for os access"
}

#
# config
#
variable "helper_dir" {
  type        = string
  description = "Directoty Path for helper script files"
}

variable "component_dir" {
  type        = string
  description = "Component Directory Path"
}

variable "config_dir" {
  type        = string
  description = "Configuration Directory Path"
}

variable "credentials_dir" {
  type        = string
  description = "Directoty Path for credential-like files"
}

variable "terraform_tmp_folder" {
  type        = string
  description = "temp folder for provisioning"
  default     = "/tmp/terraform"
}

variable "terraform_tools_folder" {
  type        = string
  description = "folder to put all tools, scripts, etc. into after provisioning is done"
  default     = "/opt/terraform"
}

#
# Instance Types
#
variable "instance_type" {
  description = "Instance type to create for the dynatrace cluster, example: Standard_D4s_v3"
}

variable "nfs_instance_type" {
  description = "Instance type to create for the NFS server, example: Standard_D2s_v3"
}

variable "cluster_active_gate_instance_type" {
  type        = string
  description = "Flavor of the instance to create for a dynatrace cluster active gate"
}

variable "cluster_synthetic_active_gate_instance_type" {
  type        = string
  description = "Flavor of the instance to create for a dynatrace cluster active gate"
}

#
# Jumpbox
#
variable "jumpbox_public_ip"{
  type = string
  description = "Public IP of jumpbox"
}

variable "jumpbox_private_ip" {
  type        = string
  description = "Private IP of jumpbox"
}

variable "jumpbox_key" {
  type        = string
  description = "Location of private SSH jumpbox key"
}

#
# volume sizes
#

variable "transaction_data_volume_size" {
  type        = number
  description = "Size of the volume for raw transaction data in GiB"
}

variable "backup_volume_size" {
  type        = number
  description = "size of the dynatrace_nfs_backup volume"
}

variable "long_term_volume_size" {
  description = "Size of the volume for long term cassandra and logsearch data in GiB"
}