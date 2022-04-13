############################################
# NSX-T provider Credentials
############################################
provider "nsxt" {
  host                 = var.nsxt_host
  username             = var.nsxt_user_name
  password             = var.nsxt_password
  allow_unverified_ssl = true
}

# NSX-T group vms based on nsxt policy vm tags
resource "nsxt_policy_group" "all_vms_group" {
  display_name = "all-vms-group"
  description  = "Group consisting of all apm vpms"
  criteria {
    condition {
      member_type = "VirtualMachine"
      operator    = "CONTAINS"
      key         = "Tag"
      value       = var.landscape_name

    }
  }
}
# NSXT security policy ssh server

resource "nsxt_policy_group" "ssh_server" {
  display_name = "ssh-server"
  description  = "group for ssh access"
  criteria {
    condition {
      member_type = "VirtualMachine"
      operator    = "CONTAINS"
      key         = "Tag"
      value       = "ssh-server"
}
  }
conjunction {
    operator = "OR"
  }
  criteria{
ipaddress_expression {
      ip_addresses = list(format("%s/32", var.jumpbox_public_ip))
    }
  }
}

resource "nsxt_policy_service" "allow_ssh" {
  display_name = "service-ssh"
  description  = "allow ssh access from jumpbox "
  l4_port_set_entry {
    display_name      = "ssh_22"
    description       = "TCP Port 22"
    protocol          = "TCP"
    destination_ports = ["22"]  
  }
}
# security policy UI
resource "nsxt_policy_group" "ui_server" {
  display_name = "ui-server"
  criteria {
    condition {
      member_type = "VirtualMachine"
      operator    = "CONTAINS"
      key         = "Tag"
      value       = "ui-server"
    }
  }
  conjunction {
    operator = "OR"
  }
  criteria{
    ipaddress_expression {
      ip_addresses = split(
        ",", 
        var.ui_allowlist_enabled ? join(
          ",", 
          concat(
            var.ui_allowlist,
            var.public_ips,
            var.cluster_active_gate_public_ips,
            var.cluster_synthetic_active_gate_public_ips,
            ) 
      ): "0.0.0.0/0",
        )
    }
  }
}

resource "nsxt_policy_service" "allow_ui" {
  display_name = "service-node-443"
  description  = "allow ui and agent traffic access to cluster nodes (443)"
  l4_port_set_entry {
    display_name      = "node_443"
    description       = "tcp port 443"
    protocol          = "TCP"
    destination_ports = ["443"]
  }
}
# security server allow API
resource "nsxt_policy_group" "api_server" {
  display_name = "api-server"
  criteria {
    condition {
      member_type = "VirtualMachine"
      operator    = "CONTAINS"
      key         = "Tag"
      value       = "api-server"
    }
  }
  conjunction {
    operator = "OR"
  }
  criteria{
    ipaddress_expression {
      ip_addresses = split(
        ",", 
        var.agent_allowlist_enabled ? join(
          ",",
          concat( 
          var.agent_allowlist,
          var.public_ips,
          var.cluster_active_gate_public_ips,
          var.cluster_synthetic_active_gate_public_ips,
          ), 
      ): "0.0.0.0/0",
      )
    }
  }
}

resource "nsxt_policy_service" "allow_api" {
  display_name = "service-node-8443"
  description  = "allow ui and agent traffic access to cluster nodes (8443)"
  l4_port_set_entry {
    display_name      = "node_8443"
    description       = "tcp port 8443"
    protocol          = "TCP"
    destination_ports = ["8443"]
  }
}

# security server Dynatrace
resource "nsxt_policy_group" "dynatrace" {
  display_name = "dynatrace"
  description  = "Group consisting dynatrace VMs"
  criteria {
    condition {
      member_type = "VirtualMachine"
      operator    = "CONTAINS"
      key         = "Tag"
      value       = "dynatrace"
    }
  }
}
resource "nsxt_policy_service" "dynatrace_mutual_access" {
  display_name = "service-dynatrace-mutual-access"
  description  = "allow dynatrace instances to access each other"
  l4_port_set_entry {
    display_name      = "dynatrace_mutual_access_1-65535"
    description       = "tcp Port 1-65535"
    protocol          = "TCP"
    destination_ports = ["1-65535"]
  }
}
#security server active gate
resource "nsxt_policy_group" "active_gate" {
  display_name = "active-gate"
  description  = "Group consisting active gate VMs"
  criteria {
    condition {
      member_type = "VirtualMachine"
      operator    = "CONTAINS"
      key         = "Tag"
      value       = "active-gate"
    }
  }
  conjunction {
    operator = "OR"
  }
  criteria {
    ipaddress_expression {
    ip_addresses      = split(",", var.agent_allowlist_enabled  ? join(",", var.agent_allowlist) : "0.0.0.0/0")
  }
}
}

resource "nsxt_policy_service" "allow_active_gate" {
  display_name = "service-dynatrace-active-gate"
  description  = "allow agent traffic towards cluster activegates (9999)"
  l4_port_set_entry {
    display_name      = "dynatrace_AG_9999"
    description       = "TCP Port 9999"
    protocol          = "TCP"
    destination_ports = ["9999"]
  }
}
#security server synthetic active gate
resource "nsxt_policy_group" "synthetic_active_gate" {
  display_name = "synthetic-active-gate"
  description  = "group consisting synthetic active gate VMs"
  criteria {
    condition {
      member_type = "VirtualMachine"
      operator    = "CONTAINS"
      key         = "Tag"
      value       = "synthetic-active-gate"
    }
  }
  conjunction {
    operator = "OR"
  }
  criteria{
    ipaddress_expression {
    ip_addresses= split(",",var.agent_allowlist_enabled ? join(",", var.agent_allowlist) : "0.0.0.0/0")
    }
  }
}
resource "nsxt_policy_service" "allow_synthetic_active_gate" {
  display_name = "service-dynatrace-synthetic-ative-gate"
  description  = "allow agent traffic towards cluster synthetic activeGates (9999)"
  l4_port_set_entry {
    display_name      = "dynatrace_SAG_9999"
    description       = "tcp Port 9999"
    protocol          = "TCP"
    destination_ports = ["9999"]
  }
}

# NSX-T firewall creation
resource "nsxt_policy_security_policy" "apm_firewall" {
  display_name = "apm-firewall"
  description  = "firewall for all apm vm's"
  scope        = [nsxt_policy_group.all_vms_group.path]
  category     = "Application"
  locked       = "false"
  stateful     = "true"
  
  rule {
    display_name       = "allow_22_access"
    description        = "allow ssh access for ssh_allowlist_group to access each other"
    action             = "ALLOW"
    logged             = "false"
    ip_version         = "IPV4"
    destination_groups = [nsxt_policy_group.ssh_server.path]
    services           = [nsxt_policy_service.allow_ssh.path]
  }
  
  rule {
    display_name       = "allow_443_access"
    description        = "allow ui allowlist ips to access dynatrace vms via 443"
    action             = "ALLOW"
    logged             = "false"
    ip_version         = "IPV4"
    destination_groups = [nsxt_policy_group.ui_server.path]
    services           = [nsxt_policy_service.allow_ui.path]
  }

  rule {
    display_name       = "allow_8443_access"
    description        = "allow agent allowlist ips to access Dynatrace vms via 443"
    action             = "ALLOW"
    logged             = "false"
    ip_version         = "IPV4"
    destination_groups = [nsxt_policy_group.api_server.path]
    services           = [nsxt_policy_service.allow_api.path]
  }

  rule {
    display_name       = "allow_1-65535_access"
    description        = "Allow dynatrace instances to access each other"
    action             = "ALLOW"
    logged             = "false"
    ip_version         = "IPV4"
    destination_groups = [nsxt_policy_group.dynatrace.path]
    services           = [nsxt_policy_service.dynatrace_mutual_access.path]
  }

  rule {
    display_name       = "allow_9999_access"
    description        = "allow agent Allowlist ips to access Dynatrace cag vms via 9999 "
    action             = "ALLOW"
    logged             = "false"
    ip_version         = "IPV4"
    destination_groups = [nsxt_policy_group.active_gate.path]
    services           = [nsxt_policy_service.allow_active_gate.path]
  }

  rule {
    display_name  = "allow out"
    description   = "outgoing rule"
    action        = "ALLOW"
    logged        = "true"
    ip_version    = "IPV4"
    source_groups = [nsxt_policy_group.ssh_server.path]
  }

  # Reject everything else
  rule {
    display_name = "deny any"
    description  = "default deny the traffic"
    action       = "REJECT"
    logged       = "true"
    ip_version   = "IPV4"
  }
}