resource "proxmox_download_file" "talos_iso" {
  content_type = "iso"
  datastore_id = var.proxmox_iso_pool
  node_name    = var.proxmox_node
  url          = data.talos_image_factory_urls.this.urls.iso
  file_name    = "talos-${var.talos_version}-nocloud-amd64.iso"
  overwrite    = false
}

resource "proxmox_virtual_environment_vm" "talos" {
  for_each = { for n in var.control_plane_nodes : n.name => n }

  name      = each.value.name
  node_name = var.proxmox_node
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
    datastore_id = var.proxmox_storage_pool
    type         = "4m"
  }

  # OS disk: empty 20G; Talos installer writes to it on first boot.
  disk {
    datastore_id = var.proxmox_storage_pool
    interface    = "scsi0"
    discard      = "on"
    size         = each.value.disk_os_gb
  }

  # Longhorn data disk: dedicated, survives `talosctl reset` of the OS disk.
  disk {
    datastore_id = var.proxmox_storage_pool
    interface    = "scsi1"
    discard      = "on"
    size         = each.value.disk_data_gb
  }

  cdrom {
    file_id   = proxmox_download_file.talos_iso.id
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
    datastore_id = var.proxmox_storage_pool
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
