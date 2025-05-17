packer {
  required_plugins {
    tart = {
      version = ">= 1.12.0"
      source  = "github.com/cirruslabs/tart"
    }
  }
}

variable "macos_version" {
  type = string
}

variable "xcode_version" {
  type = string
}

source "tart-cli" "tart" {
  vm_base_name = "ghcr.io/temap/macos-${var.macos_version}-xcode:${xcode_version}:latest"
  // use tag or the last element of the xcode_version list
  vm_name      = "${var.macos_version}-xcode:${var.tag != "" ? var.tag : var.xcode_version[0]}"
  cpu_count    = 4
  memory_gb    = 8
  disk_size_gb = var.disk_size
  headless     = true
  ssh_password = "admin"
  ssh_username = "admin"
  ssh_timeout  = "120s"
}

build {
  sources = ["source.tart-cli.tart"]

  provisioner "shell" {
    inline = [
      "source ~/.zprofile",
      "brew --version",
      "brew update",
      "brew upgrade",
    ]
  }

  // Re-install the GitHub Actions runner
  provisioner "shell" {
    script = "scripts/install-actions-runner.sh"
  }

  // make sure our workaround from base is still valid
  provisioner "shell" {
    inline = [
      "sudo ln -s /Users/admin /Users/runner || true"
    ]
  }

  # Compatibility with GitHub Actions Runner Images, where
  # /usr/local/bin belongs to the default user. Also see [2].
  #
  # [1]: https://github.com/actions/runner-images/blob/6bbddd20d76d61606bea5a0133c950cc44c370d3/images/macos/scripts/build/configure-machine.sh#L96
  # [2]: https://github.com/actions/runner-images/discussions/7607
  provisioner "shell" {
    inline = [
      "sudo chown admin /usr/local/bin"
    ]
  }
}
