# ---------- Proxmox ----------

variable "proxmox_endpoint" {
  description = "Proxmox API endpoint."
  type        = string
  default     = "https://192.168.1.250:8006/"
}

variable "proxmox_api_token" {
  description = "Proxmox API token in the form 'user@realm!tokenid=secret'."
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Name of the target Proxmox node."
  type        = string
  default     = "pve"
}

variable "proxmox_insecure" {
  description = "Skip TLS verification on the Proxmox API."
  type        = bool
  default     = true
}

variable "proxmox_ssh_user" {
  description = "SSH user for the Proxmox host (used by bpg/proxmox for image import)."
  type        = string
  default     = "root"
}

variable "proxmox_storage_pool" {
  description = "Storage pool for VM disks."
  type        = string
  default     = "zfs0"
}

variable "proxmox_iso_pool" {
  description = "Storage pool for the Talos ISO/qcow image."
  type        = string
  default     = "local"
}

variable "proxmox_bridge" {
  description = "Linux bridge used for VM networking."
  type        = string
  default     = "vmbr0"
}

# ---------- Cluster ----------

variable "cluster_name" {
  description = "Talos cluster name."
  type        = string
  default     = "homelab"
}

variable "cluster_endpoint_ip" {
  description = "Floating or first control-plane IP used as the Talos cluster endpoint."
  type        = string
  default     = "192.168.1.50"
}

variable "control_plane_nodes" {
  description = "Three combined CP+worker VMs. disk_os_gb = Talos OS + EPHEMERAL (kubelet, images, logs). disk_data_gb = dedicated Longhorn data disk."
  type = list(object({
    name         = string
    cpu          = number
    memory       = number
    disk_os_gb   = number
    disk_data_gb = number
    ip           = string
    gw           = string
    mac          = optional(string)
    vmid         = optional(number)
  }))
  default = [
    { name = "talos-cp-0", vmid = 2000, cpu = 4, memory = 8192, disk_os_gb = 20, disk_data_gb = 70, ip = "192.168.1.50", gw = "192.168.1.254" },
    { name = "talos-cp-1", vmid = 2001, cpu = 4, memory = 8192, disk_os_gb = 20, disk_data_gb = 70, ip = "192.168.1.51", gw = "192.168.1.254" },
    { name = "talos-cp-2", vmid = 2002, cpu = 4, memory = 8192, disk_os_gb = 20, disk_data_gb = 70, ip = "192.168.1.52", gw = "192.168.1.254" },
  ]
  validation {
    condition     = length(var.control_plane_nodes) == 3
    error_message = "Phase 1 expects exactly 3 control-plane nodes."
  }
}

variable "talos_version" {
  description = "Talos image version."
  type        = string
  default     = "v1.13.0"
}

variable "kubernetes_version" {
  description = "Kubernetes version."
  type        = string
  default     = "1.36.0"
}

# ---------- Cloudflare ----------

variable "cloudflare_api_token" {
  description = "Cloudflare API token used by Tofu (account-scoped: tunnel, tokens, DNS)."
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID."
  type        = string
  default     = "73cc895f8fc761e9d76a9da012c86478"
}

variable "cloudflare_zone" {
  description = "Cloudflare zone name."
  type        = string
  default     = "joelmccoy.dev"
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for var.cloudflare_zone."
  type        = string
  default     = "1f8994f63fc0680528874de737bc2e8c"
}
