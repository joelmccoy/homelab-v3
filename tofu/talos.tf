locals {
  # Talos image factory schematic — extensions baked into the image.
  talos_schematic = {
    customization = {
      systemExtensions = {
        officialExtensions = [
          "siderolabs/iscsi-tools",
          "siderolabs/util-linux-tools",
          "siderolabs/qemu-guest-agent",
        ]
      }
    }
  }
}

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode(local.talos_schematic)
}

data "talos_image_factory_urls" "this" {
  talos_version = var.talos_version
  schematic_id  = talos_image_factory_schematic.this.id
  platform      = "nocloud"
  architecture  = "amd64"
}

# ---------------- Machine configuration ----------------

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

data "talos_machine_configuration" "controlplane" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${var.cluster_endpoint_ip}:6443"
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = var.kubernetes_version
  talos_version      = var.talos_version

  config_patches = [
    yamlencode({
      cluster = {
        allowSchedulingOnControlPlanes = true
        network = {
          cni = { name = "none" }
        }
        proxy = {
          disabled = true
        }
      }
      machine = {
        install = {
          image = data.talos_image_factory_urls.this.urls.installer
        }
        kubelet = {
          extraArgs = {
            rotate-server-certificates = "true"
          }
        }
        kernel = {
          modules = [
            { name = "iscsi_tcp" },
            { name = "dm_crypt" },
          ]
        }
      }
    }),
  ]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for n in var.control_plane_nodes : n.ip]
  nodes                = [for n in var.control_plane_nodes : n.ip]
}

resource "talos_machine_configuration_apply" "controlplane" {
  for_each = { for n in var.control_plane_nodes : n.name => n }

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  endpoint                    = each.value.ip
  node                        = each.value.ip
  apply_mode                  = "reboot"

  config_patches = [
    yamlencode({
      machine = {
        # network hostname/IP set by Proxmox cloud-init drive (NoCloud platform).
        install = {
          disk = "/dev/sda"
        }
        disks = [
          {
            device = "/dev/sdb"
            partitions = [
              {
                mountpoint = "/var/mnt/longhorn-data"
              },
            ]
          },
        ]
      }
    }),
  ]

  depends_on = [proxmox_virtual_environment_vm.talos]
}

resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint             = var.control_plane_nodes[0].ip
  node                 = var.control_plane_nodes[0].ip

  depends_on = [talos_machine_configuration_apply.controlplane]
}

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint             = var.cluster_endpoint_ip
  node                 = var.control_plane_nodes[0].ip

  depends_on = [talos_machine_bootstrap.this]
}
