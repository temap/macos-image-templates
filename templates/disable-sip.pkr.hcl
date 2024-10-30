packer {
  required_plugins {
    tart = {
      version = ">= 1.14.0"
      source  = "github.com/cirruslabs/tart"
    }
  }
}

variable "vm_name" {
  type = string
}

variable "password" {
  type = string
  default = "distiller"
}

source "tart-cli" "tart" {
  vm_name      = "${var.vm_name}"
  recovery     = true
  cpu_count    = 4
  memory_gb    = 8
  disk_size_gb = 80
  communicator = "none"
  boot_command = [
    # Skip over "Macintosh" and select "Options"
    # to boot into macOS Recovery
    "<wait60s><right><right><enter>",
    # Open Terminal
    "<wait10s><leftAltOn>T<leftAltOff>",
    # Disable SIP
    "<wait10s>csrutil disable<enter>",
    "<wait10s>y<enter>",
    "<wait10s>${var.password}<enter>",
    # Shutdown
    "<wait10s>halt<enter>"
  ]
}

build {
  sources = ["source.tart-cli.tart"]
}