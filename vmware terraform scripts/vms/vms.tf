##############################################
#VMware Vsphere provider Credentials
##############################################
provider "vsphere" {
  vsphere_server       = var.vcenter_host
  user                 = var.vcenter_user_name
  password             = var.vcenter_password
  allow_unverified_ssl = true
}

#NSX-T provider
provider "nsxt" {
  host                 = var.nsxt_host
  username             = var.nsxt_user_name
  password             = var.nsxt_password
  allow_unverified_ssl = true
}

#VMware Vsphere Datacenter
data "vsphere_datacenter" "dc" {
  name = var.vsphere_datacenter
}

#VMware Vsphere Datastore
data "vsphere_datastore" "datastore" {
  count         = length(var.vsphere_datastore)
  name          = var.vsphere_datastore[count.index]
  datacenter_id = data.vsphere_datacenter.dc.id
}

#Vmware Vsphere Resource Pool
data "vsphere_resource_pool" "pool" {
  count         = length(var.availability_zones)
  name          = "${var.availability_zones[count.index]}/Resources"
  datacenter_id = data.vsphere_datacenter.dc.id
}

#VMware Vsphere Distributed Virtual Switch
data "vsphere_distributed_virtual_switch" "dvs" {
  count         = length(var.vsphere_distributed_virtual_switch)
  name          = var.vsphere_distributed_virtual_switch[count.index]
  datacenter_id = data.vsphere_datacenter.dc.id
}

#Vmware Vsphere Dynatrace Segment
data "vsphere_network" "apm_network" {
  count                           = length(var.vsphere_distributed_virtual_switch)
  name                            = var.nsxt_policy_network_segment
  datacenter_id                   = data.vsphere_datacenter.dc.id
  distributed_virtual_switch_uuid = data.vsphere_distributed_virtual_switch.dvs[count.index].id
}

# NSXT Tier-1 gateway
data "nsxt_policy_tier1_gateway" "t1_gateway" {
  display_name = var.nsxt_policy_tier1_gateway
}

#Vmware Vsphere Content Library
data "vsphere_content_library" "library" {
  name        = var.vsphere_content_library
}

data "vsphere_content_library_item" "item" {
  name       = var.vsphere_content_library_item_name
  library_id = data.vsphere_content_library.library.id
}

# Cloud init config
data "template_cloudinit_config" "config" {
  gzip          = true
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content = <<-EOF
      #cloud-config
      hostname: "ubuntu-${var.landscape_name}-dynatrace"
      users:
        - name: "${var.os_user}"
          passwd: 'admin'
          lock_passwd: true
          ssh-authorized-keys:
            - file("${var.credentials_dir}/dynatrace.pub")
      runcmd:
        - sed -i '/ubuntu insecure public key/d' /home/ubuntu/.ssh/authorized_keys
        - usermod --expiredate '' ubuntu
      EOF
  }
}

#Vmware Vsphere folder
data "vsphere_folder" "apm_folder" {
  path = "/${var.vsphere_datacenter}/vm/apm"
}

#############################
# Vsphere Virtual Machines
#############################
#Vmware Vsphere virtual Machine " Dynatrace instances"
resource "vsphere_virtual_machine" "dynatrace-server" {
  count                       = var.instances
  name                        = "dynatrace-${count.index}-${var.landscape_name}"
  folder                      = data.vsphere_folder.apm_folder.path
  resource_pool_id            = data.vsphere_resource_pool.pool[ count.index %  length(var.availability_zones)].id
  datastore_id                = data.vsphere_datastore.datastore[ count.index %  length(var.vsphere_datastore)].id
  wait_for_guest_net_routable = true
  num_cpus                    = trimsuffix("${element(split("_", var.instance_type),0)}","cpu")
  memory                      = trimsuffix("${element(split("_", var.instance_type),1)}","gb")*1024
  guest_id                    = var.guest_id
  cdrom {
    client_device = true
  }
  network_interface {
    network_id = data.vsphere_network.apm_network[ count.index %  length(var.vsphere_distributed_virtual_switch)].id
  }
  disk {
    label = "disk0"
    size  = var.root_volume_size
    thin_provisioned = false
  }

  #Attach aditional Volumes " dynatrace opt storage volume "
  disk {
    attach       = true
    path         = element(split(",", var.dynatrace_opt_storage_volume_vmdk_path), count.index)
    label        = "dynatrace_opt_storage_volume-${count.index}-${var.landscape_name}"
    disk_mode    = "independent_persistent"
    unit_number  = 1
    datastore_id = data.vsphere_datastore.datastore[ count.index %  length(var.vsphere_datastore)].id
  }

  #Attach additional Volumes " dynatrace transaction data volume "
  disk {
    attach       = true
    path         = element(split(",", var.dynatrace_transaction_data_volume_vmdk_path), count.index)
    label        = "dynatrace_transaction_data_volume-${count.index}-${var.landscape_name}"
    disk_mode    = "independent_persistent"
    unit_number  = 2
    datastore_id = data.vsphere_datastore.datastore[ count.index %  length(var.vsphere_datastore)].id
  }

  #Attach additional Volumes " dynatrace long term volume "
  disk {
    attach       = true
    path         = element(split(",", var.dynatrace_long_term_volume_vmdk_path), count.index)
    label        = "dynatrace_long_term_volume-${count.index}-${var.landscape_name}"
    disk_mode    = "independent_persistent"
    unit_number  = 3
    datastore_id = data.vsphere_datastore.datastore[ count.index %  length(var.vsphere_datastore)].id
  }

  clone {
    template_uuid = data.vsphere_content_library_item.item.id
  } 

  extra_config = {
    "guestinfo.userdata" = data.template_cloudinit_config.config.rendered
    "guestinfo.userdata.encoding" = "gzip+base64"
  }

    vapp {
    properties = {
      "public-keys" = file("${var.credentials_dir}/dynatrace.pub")
      "hostname"    = "dynatrace-${count.index}-${var.landscape_name}"
    }
  }
}

#VMware Vsphere Dynatrace Public IP assigning by NSXT natting
resource "nsxt_policy_nat_rule" "dynatrace_nat" {
  count                = var.instances
  display_name         = "dynatrace-nat-public-${count.index}-${var.landscape_name}"
  action               = "DNAT"
  destination_networks = formatlist("%s", element(var.public_ips, count.index))
  translated_networks  = formatlist("%s",element(vsphere_virtual_machine.dynatrace-server.*.default_ip_address, count.index))
  firewall_match        = "MATCH_INTERNAL_ADDRESS"
  logging               = true
  gateway_path         = data.nsxt_policy_tier1_gateway.t1_gateway.path
}

#Vmware Vsphere virtual Machine " Dynatrace cluster active gate instances "
resource "vsphere_virtual_machine" "dynatrace-cluster-active-gate" {
  count                       = var.cluster_active_gate_instances
  folder                      = data.vsphere_folder.apm_folder.path             
  name                        = "dynatrace-public-active-gate-${count.index}-${var.landscape_name}"
  resource_pool_id            = data.vsphere_resource_pool.pool[ count.index %  length(var.availability_zones)].id
  datastore_id                = data.vsphere_datastore.datastore[ count.index %  length(var.vsphere_datastore)].id
  wait_for_guest_net_routable = true
  num_cpus                    = trimsuffix("${element(split("_", var.cluster_active_gate_instance_type),0)}","cpu")
  memory                      = trimsuffix("${element(split("_", var.cluster_active_gate_instance_type),1)}","gb")*1024
  guest_id                    = var.guest_id
  cdrom {
    client_device = true
  }
  network_interface {
    network_id = data.vsphere_network.apm_network[ count.index %  length(var.vsphere_distributed_virtual_switch)].id
  }
  disk {
    label = "disk0"
    size  = var.root_volume_size
    thin_provisioned = false
  }

  clone {
    template_uuid = data.vsphere_content_library_item.item.id
  } 

  extra_config = {
    "guestinfo.userdata" = data.template_cloudinit_config.config.rendered
    "guestinfo.userdata.encoding" = "gzip+base64"
  }

    vapp {
    properties = {
      "public-keys" = file("${var.credentials_dir}/dynatrace.pub")
      "hostname"    = "dynatrace-public-active-gate-${count.index}-${var.landscape_name}"
    }
  }
}

#VMware Vsphere Dynatrace active gate Public IP assigning by NSXT natting
resource "nsxt_policy_nat_rule" "dynatrace_cluster_active_gate_nat" {
  count                = var.cluster_active_gate_instances
  display_name         = "dynatrace-cluster-active-gate-nat-public-${count.index}-${var.landscape_name}"
  action               = "DNAT"
  destination_networks =  formatlist("%s", element(var.cluster_active_gate_public_ips, count.index))
  translated_networks  = formatlist("%s", element(vsphere_virtual_machine.dynatrace-cluster-active-gate.*.default_ip_address, count.index))
  firewall_match        = "MATCH_INTERNAL_ADDRESS"
  logging               = true
  gateway_path         = data.nsxt_policy_tier1_gateway.t1_gateway.path
}

#Vmware Vsphere virtual Machine " Dynatrace cluster synthetic active gate instances "
resource "vsphere_virtual_machine" "dynatrace-cluster-synthetic-active-gate" {
  count                       = var.cluster_synthetic_active_gate_instances
  folder                      = data.vsphere_folder.apm_folder.path             
  name                        = "dynatrace-public-synthetic-active-gate-${count.index}-${var.landscape_name}"
  resource_pool_id            = data.vsphere_resource_pool.pool[ count.index %  length(var.availability_zones)].id
  datastore_id                = data.vsphere_datastore.datastore[ count.index %  length(var.vsphere_datastore)].id
  wait_for_guest_net_routable = true
  num_cpus                    = trimsuffix("${element(split("_", var.cluster_synthetic_active_gate_instance_type),0)}","cpu")
  memory                      = trimsuffix("${element(split("_", var.cluster_synthetic_active_gate_instance_type),1)}","gb")*1024
  guest_id                    = var.guest_id
  cdrom {
    client_device = true
  }
  network_interface {
    network_id = data.vsphere_network.apm_network[ count.index %  length(var.vsphere_distributed_virtual_switch)].id
  }
  disk {
    label = "disk0"
    size  = 30
    thin_provisioned = false
  }

  clone {
    template_uuid = data.vsphere_content_library_item.item.id
  }

  extra_config = {
    "guestinfo.userdata" = data.template_cloudinit_config.config.rendered
    "guestinfo.userdata.encoding" = "gzip+base64"
  }

    vapp {
    properties = {
      "public-keys" = file("${var.credentials_dir}/dynatrace.pub")
      "hostname"    = "dynatrace-public-synthetic-active-gate-${count.index}-${var.landscape_name}"
    }
  }
}

#VMware Vsphere Dynatrace synthetic active gate Public IP assigning by NSXT natting
resource "nsxt_policy_nat_rule" "dynatrace_cluster_synthetic_active_gate_nat" {
  count                = var.cluster_synthetic_active_gate_instances
  display_name         = "dynatrace-cluster-synthetic_active-gate-nat-public-${count.index}-${var.landscape_name}"
  action               = "DNAT"
  translated_networks  = formatlist("%s", element(vsphere_virtual_machine.dynatrace-cluster-synthetic-active-gate.*.default_ip_address, count.index))
  destination_networks = formatlist("%s", element(var.cluster_synthetic_active_gate_public_ips, count.index))
  firewall_match        = "MATCH_INTERNAL_ADDRESS"
  logging               = true
  gateway_path         = data.nsxt_policy_tier1_gateway.t1_gateway.path
}

#Vmware Vsphere virtual Machine " NFS Server instances"
resource "vsphere_virtual_machine" "nfs-server" {
  count                       = 1
  name                        = "nfs-server-${count.index}-${var.landscape_name}"
  folder                      = data.vsphere_folder.apm_folder.path
  resource_pool_id            = data.vsphere_resource_pool.pool[ count.index %  length(var.availability_zones)].id
  datastore_id                = data.vsphere_datastore.datastore[ count.index %  length(var.vsphere_datastore)].id
  wait_for_guest_net_routable = true
  num_cpus                    = trimsuffix("${element(split("_", var.nfs_instance_type),0)}","cpu")
  memory                      = trimsuffix("${element(split("_", var.nfs_instance_type),1)}","gb")*1024
  guest_id                    = var.guest_id
  cdrom {
    client_device = true
  }
  network_interface {
    network_id = data.vsphere_network.apm_network[ count.index %  length(var.vsphere_distributed_virtual_switch)].id
  }
  disk {
    label = "disk0"
    size  = var.root_volume_size
    thin_provisioned = false
  }

  #Attach additional Volumes nfs backup volume 
  disk {
    attach       = true
    path         = element(split(",", var.dynatrace_nfs_backup_volume_vmdk_path), count.index)
    label        = "dynatrace_nfs_backup_volume-${count.index}-${var.landscape_name}"
    disk_mode    = "independent_persistent"
    unit_number  = 1
    datastore_id = data.vsphere_datastore.datastore[ count.index %  length(var.vsphere_datastore)].id
  }

  clone {
    template_uuid = data.vsphere_content_library_item.item.id
  } 

  extra_config = {
    "guestinfo.userdata" = data.template_cloudinit_config.config.rendered
    "guestinfo.userdata.encoding" = "gzip+base64"
  }

    vapp {
    properties = {
      "public-keys" = file("${var.credentials_dir}/dynatrace.pub")
      "hostname"    = "nfs-server-${count.index}-${var.landscape_name}"
    }
  }
}

#Post provisioning tasks / install required packages
resource "null_resource" "install_packages" {
  count      = var.instances
  depends_on = [vsphere_virtual_machine.dynatrace-server]

  # Changes to any instance of the cluster requires re-provisioning
  triggers = {
    cluster_instance_ids = join(",", vsphere_virtual_machine.dynatrace-server.*.id)
  }

  connection {
    type                = "ssh"
    host                = element(vsphere_virtual_machine.dynatrace-server.*.default_ip_address, count.index)
    user                = var.os_user
    private_key         = file("${var.credentials_dir}/dynatrace.pem")
    timeout             = "5m"
    agent               = false
    bastion_host        = var.jumpbox_public_ip
    bastion_private_key = file(var.jumpbox_key)
    bastion_user        = "ubuntu" 
  }

  #install required apt-get packages
  provisioner "remote-exec" {
    inline = [<<EOC
      set -e
      timeout 180 /usr/bin/env bash -c \
      'until stat /var/lib/cloud/instance/boot-finished 2>/dev/null; do \
      echo "Waiting for instance boot finished..."; sleep 1; done'
      sudo sed -i -e "s/\\(.*127.0.0.1\\s*$(hostname)\\)/\\1/;t;1i127.0.0.1\t$(hostname)" /etc/hosts
      echo 'Updating package list...'
      sudo apt-get -q update
      echo "Upgrading installed packages..."
      sudo DEBIAN_FRONTEND=noninteractive sh -c 'apt-get -o Dpkg::Options::="--force-confnew" -q -y --with-new-pkgs upgrade'
      echo 'Installing additional packages...'
      sudo apt-get -qq install lvm2 jq unzip ntp lsscsi
    EOC
    ]
  }
}

#Format volumes and attach_volumes
resource "null_resource" "attach_volumes" {
  count      = var.instances
  depends_on = [
    vsphere_virtual_machine.dynatrace-server,
    null_resource.install_packages,
    ]
  
  # Changes to any instance of the cluster requires re-provisioning
  triggers = {
    cluster_instance_ids = join(",", vsphere_virtual_machine.dynatrace-server.*.id)
  }
  connection {
    type                = "ssh"
    host                = element(vsphere_virtual_machine.dynatrace-server.*.default_ip_address, count.index)
    user                = var.os_user
    private_key         = file("${var.credentials_dir}/dynatrace.pem")
    timeout             = "5m"
    agent               = false
    bastion_host        = var.jumpbox_public_ip
    bastion_private_key = file(var.jumpbox_key)
    bastion_user        = "ubuntu"
  }

  provisioner "remote-exec" {
    inline = [<<EOC
      mkdir -p ${var.terraform_tmp_folder}
    EOC
    ]
  }

  # provision whole helper folder
  provisioner "file" {
    source      = "${var.helper_dir}/"
    destination = var.terraform_tmp_folder
  }

  # - mount and prepare volumes
  provisioner "remote-exec" {
    inline = [<<EOC
      set -e
      chmod a+x ${var.terraform_tmp_folder}/*.sh
      echo Preparing volumes...
      # Used to detect disk using lun parameter
      lsscsi
      sudo ln -sf "/dev/sdd" "/dev/dynatrace_longterm_data_disk"
      sudo ${var.terraform_tmp_folder}/mount-lvm.sh dynatrace_longterm_data_disk ${var.dynatrace_longterm_data_volume_mount} ${var.os_user}
      sudo ln -sf "/dev/sdb" "/dev/dynatrace_storage_disk"
      sudo ${var.terraform_tmp_folder}/mount-lvm.sh dynatrace_storage_disk ${var.dynatrace_opt_volume_mount} ${var.os_user}
      sudo ln -sf "/dev/sdc" "/dev/dynatrace_transaction_data_disk"
      sudo ${var.terraform_tmp_folder}/mount-lvm.sh dynatrace_transaction_data_disk ${var.dynatrace_raw_data_volume_mount} ${var.os_user}
      echo "Copying tools to ${var.terraform_tools_folder}"
      sudo cp -a ${var.terraform_tmp_folder}/. ${var.terraform_tools_folder}/
    EOC
    ]
  }
}

#Prepare NFS server
resource "null_resource" "prepare_nfs_server" {
    count = 1
    depends_on = [
      vsphere_virtual_machine.nfs-server,
      vsphere_virtual_machine.dynatrace-server,
      null_resource.install_packages,
      ]

  # Changes to any nfs server or dynatrace cluster instance requires re-provisioning
  triggers = {
    cluster_instance_ids = join(",",vsphere_virtual_machine.dynatrace-server.*.id)
  }

  connection {
    type                = "ssh"
    host                = element(vsphere_virtual_machine.nfs-server.*.default_ip_address, count.index)
    user                = var.os_user
    private_key         = file("${var.credentials_dir}/dynatrace.pem")
    timeout             = "5m"
    agent               = false
    bastion_host        = var.jumpbox_public_ip
    bastion_private_key = file(var.jumpbox_key)
    bastion_user        = "ubuntu"
  }

  provisioner "remote-exec" {
    inline = [<<EOC
      set -e
      mkdir  -p ${var.terraform_tmp_folder}
      EOC
    ]
  }

  # provision whole helper folder
  provisioner "file" {
    source      = "${var.helper_dir}/"
    destination = var.terraform_tmp_folder
  }

  # install required apt-get packages
  provisioner "remote-exec" {
    inline = [<<EOC
      set -e
      timeout 180 /usr/bin/env bash -c \
      'until stat /var/lib/cloud/instance/boot-finished 2>/dev/null; do \
      echo "Waiting for instance boot finished..."; sleep 1; done'
      sudo sed -i -e "s/\\(.*127.0.0.1\\s*$(hostname)\\)/\\1/;t;1i127.0.0.1\t$(hostname)" /etc/hosts
      echo "Updating apt-get package list..."
      sudo apt-get -q update
      echo "Upgrading installed packages..."
      sudo DEBIAN_FRONTEND=noninteractive sh -c 'apt-get -o Dpkg::Options::="--force-confnew" -q -y --with-new-pkgs upgrade'
      echo "Installing additional packages..."
      sudo apt-get -qq install lvm2 jq unzip ntp nfs-kernel-server lsscsi
      echo "Preparing volumes..."
      sudo ln -sf "/dev/sdb" "/dev/dynatrace_nfs_backup_disk"
      chmod a+x ${var.terraform_tmp_folder}/*.sh
      sudo ${var.terraform_tmp_folder}/mount-lvm.sh dynatrace_nfs_backup_disk ${var.dynatrace_backup_nfs_mount} ${var.os_user}
      echo "Copying tools to ${var.terraform_tools_folder}"
      sudo cp -a ${var.terraform_tmp_folder}/. ${var.terraform_tools_folder}/
      echo "Exporting NFS volumes..."
      sudo su -c "cat /etc/exports | grep -q '${var.dynatrace_backup_nfs_mount}' || { echo '${var.dynatrace_backup_nfs_mount} ${element(vsphere_virtual_machine.nfs-server.*.default_ip_address, 0)}/16(rw,sync,no_subtree_check,no_root_squash)' >> /etc/exports; }"
      sudo /etc/init.d/nfs-kernel-server restart
    EOC
    ]
  }
}

#Prepare NFS client in dynatrace instances
resource "null_resource" "prepare_nfs_client" {
  count = var.instances
  depends_on = [
    null_resource.attach_volumes,
    null_resource.prepare_nfs_server]

  # Changes to any instance of the cluster requires re-provisioning
  triggers = {
    cluster_instance_ids = join(",", vsphere_virtual_machine.dynatrace-server.*.id)
  }

  connection {
    type                = "ssh"
    host                = element(vsphere_virtual_machine.dynatrace-server.*.default_ip_address, count.index)
    user                = var.os_user
    private_key         = file("${var.credentials_dir}/dynatrace.pem")
    timeout             = "5m"
    agent               = false
    bastion_host        = var.jumpbox_public_ip
    bastion_private_key = file(var.jumpbox_key)
    bastion_user        = "ubuntu"
  }

  # - install required apt-get packages
  # - mount and prepare NFS volumes
  provisioner "remote-exec" {
    inline = [<<EOC
      set -e
      echo "Installing nfs-common..."
      sudo  apt-get -qq install nfs-common
      echo "Preparing NFS volumes..."
      sudo umount ${var.dynatrace_backup_nfs_mount} || echo "Unmounting ${var.dynatrace_backup_nfs_mount} failed, will continue anyway..."
      sudo mkdir -p ${var.dynatrace_backup_nfs_mount}
      sudo chown -R ${var.os_user} ${var.dynatrace_backup_nfs_mount}
      sudo mount -t nfs -o vers=3 ${element(vsphere_virtual_machine.nfs-server.*.default_ip_address, 0)}:${var.dynatrace_backup_nfs_mount} ${var.dynatrace_backup_nfs_mount}
      sudo su -c "cat /etc/fstab | grep -q '${element(vsphere_virtual_machine.nfs-server.*.default_ip_address, 0)}' || { echo '${element(vsphere_virtual_machine.nfs-server.*.default_ip_address, 0)}:${var.dynatrace_backup_nfs_mount} ${var.dynatrace_backup_nfs_mount} nfs defaults 0 0' >> /etc/fstab; }"
EOC
    ]
  }
}

# Exports
output "dynatrace_private_ips" {
  value = vsphere_virtual_machine.dynatrace-server.*.default_ip_address
}

output "dynatrace_public_ips" {
  value = var.public_ips
}

output "dynatrace_cluster_active_gate_ips" {
  value = var.cluster_active_gate_public_ips
}

output "dynatrace_cluster_active_gate_private_ips" {
  value = vsphere_virtual_machine.dynatrace-cluster-active-gate.*.default_ip_address
}

output "dynatrace_cluster_synthetic_active_gate_ips" {
  value = var.cluster_synthetic_active_gate_public_ips
}

output "dynatrace_cluster_synthetic_active_gate_private_ips" {
  value = vsphere_virtual_machine.dynatrace-cluster-synthetic-active-gate.*.default_ip_address
}

output "nfs_private_ip" {
  value = vsphere_virtual_machine.nfs-server.*.default_ip_address
}

output "dynatrace_keyname" {
  value = "dynatrace-${var.landscape_name}"
}

output "dynatrace_public_key" {
  value = file("${var.credentials_dir}/dynatrace.pub")
}
output "dynatrace_private_key" {
  value = file("${var.credentials_dir}/dynatrace.pem")
}
