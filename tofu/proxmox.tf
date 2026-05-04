locals {
  # Talos ISO must exist in `local` storage on every Proxmox host that runs
  # Talos VMs — `local` is per-node (each PVE has its own /var/lib/vz).
  talos_iso_proxmox_nodes = toset(concat(
    [var.proxmox_node],
    [for n in var.control_plane_nodes : coalesce(n.proxmox_node, var.proxmox_node)],
    [for n in var.worker_nodes : coalesce(n.proxmox_node, var.proxmox_node)],
  ))

  # Per-VM storage pool: `pve` (the storage host) uses the dedicated zfs pool;
  # other Proxmox hosts use their built-in local-lvm thin pool.
  cp_node_storage = {
    for n in var.control_plane_nodes :
    n.name => coalesce(n.proxmox_node, var.proxmox_node) == var.proxmox_node ? var.proxmox_storage_pool : "local-lvm"
  }
  worker_node_storage = {
    for n in var.worker_nodes :
    n.name => coalesce(n.proxmox_node, var.proxmox_node) == var.proxmox_node ? var.proxmox_storage_pool : "local-lvm"
  }
}

resource "proxmox_download_file" "talos_iso" {
  for_each = local.talos_iso_proxmox_nodes

  content_type = "iso"
  datastore_id = var.proxmox_iso_pool
  node_name    = each.value
  url          = data.talos_image_factory_urls.this.urls.iso
  file_name    = "talos-${var.talos_version}-nocloud-amd64.iso"
  overwrite    = false
}

# Preserve state: existing single-instance download is now keyed by node.
moved {
  from = proxmox_download_file.talos_iso
  to   = proxmox_download_file.talos_iso["pve"]
}

resource "proxmox_virtual_environment_vm" "talos" {
  for_each = { for n in var.control_plane_nodes : n.name => n }

  name      = each.value.name
  node_name = coalesce(each.value.proxmox_node, var.proxmox_node)
  vm_id     = try(each.value.vmid, null)

  agent {
    enabled = true
  }

  bios    = "ovmf"
  machine = "q35"

  cpu {
    cores = each.value.cpu
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
    floating  = 0
  }

  efi_disk {
    datastore_id = local.cp_node_storage[each.key]
    type         = "4m"
  }

  # OS disk: empty 20G; Talos installer writes to it on first boot.
  disk {
    datastore_id = local.cp_node_storage[each.key]
    interface    = "scsi0"
    discard      = "on"
    size         = each.value.disk_os_gb
  }

  # Longhorn data disk: dedicated, survives `talosctl reset` of the OS disk.
  disk {
    datastore_id = local.cp_node_storage[each.key]
    interface    = "scsi1"
    discard      = "on"
    size         = each.value.disk_data_gb
  }

  cdrom {
    file_id   = proxmox_download_file.talos_iso[coalesce(each.value.proxmox_node, var.proxmox_node)].id
    interface = "ide2"
  }

  network_device {
    bridge      = var.proxmox_bridge
    model       = "virtio"
    mac_address = try(each.value.mac, null)
  }

  operating_system {
    type = "l26"
  }

  serial_device {}

  # Boot CD-ROM first so Talos installer runs on first boot;
  # after install, Talos lands on disk and BIOS falls through to scsi0.
  boot_order = ["ide2", "scsi0"]

  initialization {
    datastore_id = local.cp_node_storage[each.key]
    interface    = "ide3"

    dns {
      servers = ["1.1.1.1", "1.0.0.1"]
    }

    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = each.value.gw
      }
    }
  }

  on_boot         = true
  reboot          = false
  stop_on_destroy = true
}

# Talos workers — same image, smaller default footprint, pinned to whichever
# Proxmox host the node object names (defaults to var.proxmox_node).
resource "proxmox_virtual_environment_vm" "talos_worker" {
  for_each = { for n in var.worker_nodes : n.name => n }

  name      = each.value.name
  node_name = coalesce(each.value.proxmox_node, var.proxmox_node)
  vm_id     = try(each.value.vmid, null)

  agent {
    enabled = true
  }

  bios    = "ovmf"
  machine = "q35"

  cpu {
    cores = each.value.cpu
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
    floating  = 0
  }

  efi_disk {
    # Workers placed on a non-storage host (e.g. pve1) write to that host's
    # local-lvm; cp VMs on `pve` keep using zfs0.
    datastore_id = local.worker_node_storage[each.key]
    type         = "4m"
  }

  disk {
    datastore_id = local.worker_node_storage[each.key]
    interface    = "scsi0"
    discard      = "on"
    size         = each.value.disk_os_gb
  }

  disk {
    datastore_id = local.worker_node_storage[each.key]
    interface    = "scsi1"
    discard      = "on"
    size         = each.value.disk_data_gb
  }

  cdrom {
    file_id   = proxmox_download_file.talos_iso[coalesce(each.value.proxmox_node, var.proxmox_node)].id
    interface = "ide2"
  }

  network_device {
    bridge      = var.proxmox_bridge
    model       = "virtio"
    mac_address = try(each.value.mac, null)
  }

  operating_system {
    type = "l26"
  }

  serial_device {}

  boot_order = ["ide2", "scsi0"]

  initialization {
    datastore_id = local.worker_node_storage[each.key]
    interface    = "ide3"

    dns {
      servers = ["1.1.1.1", "1.0.0.1"]
    }

    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = each.value.gw
      }
    }
  }

  on_boot         = true
  reboot          = false
  stop_on_destroy = true
}
