packer {
  required_plugins {
    tart = {
      version = ">= 1.14.0"
      source  = "github.com/cirruslabs/tart"
    }
  }
}

variable "username" {
  type = string
  default = "distiller"
}

variable "password" {
  type = string
  default = "distiller"
}

variable "disk_free_mb" {
  type    = number
  default = 30000
}

variable "xcode_version" {
  type    = string
  default = "16"
}

variable "additional_runtimes" {
  type    = list(string)
  default = []
}

source "tart-cli" "tart" {
  from_ipsw    = "https://updates.cdn-apple.com/2024SummerFCS/fullrestores/062-52859/932E0A8F-6644-4759-82DA-F8FA8DEA806A/UniversalMac_14.6.1_23G93_Restore.ipsw"
  vm_name      = "sonoma-circleci"
  cpu_count    = 4
  memory_gb    = 8
  disk_size_gb = 80
  ssh_password = var.password
  ssh_username = var.username
  ssh_timeout  = "120s"
  boot_command = [
    # hello, hola, bonjour, etc.
    "<wait30s><spacebar>",
    # Language: most of the times we have a list of "English"[1], "English (UK)", etc. with
    # "English" language already selected. If we type "english", it'll cause us to switch
    # to the "English (UK)", which is not what we want. To solve this, we switch to some other
    # language first, e.g. "Italiano" and then switch back to "English". We'll then jump to the
    # first entry in a list of "english"-prefixed items, which will be "English".
    #
    # [1]: should be named "English (US)", but oh well 🤷
    "<wait15s>italiano<esc>english<enter>",
    # Select Your Country and Region
    "<wait15s>united states<leftShiftOn><tab><leftShiftOff><spacebar>",
    # Written and Spoken Languages
    "<wait5s><leftShiftOn><tab><leftShiftOff><spacebar>",
    # Accessibility
    "<wait5s><leftShiftOn><tab><leftShiftOff><spacebar>",
    # Data & Privacy
    "<wait5s><leftShiftOn><tab><leftShiftOff><spacebar>",
    # Migration Assistant
    "<wait5s><tab><tab><tab><spacebar>",
    # Sign In with Your Apple ID
    "<wait5s><leftShiftOn><tab><leftShiftOff><leftShiftOn><tab><leftShiftOff><spacebar>",
    # Are you sure you want to skip signing in with an Apple ID?
    "<wait5s><tab><spacebar>",
    # Terms and Conditions
    "<wait5s><leftShiftOn><tab><leftShiftOff><spacebar>",
    # I have read and agree to the macOS Software License Agreement
    "<wait5s><tab><spacebar>",
    # Create a Computer Account
    "<wait5s>${var.username}<tab><tab>${var.password}<tab>${var.password}<tab><tab><tab><spacebar>",
    # Enable Location Services
    "<wait20s><leftShiftOn><tab><leftShiftOff><spacebar>",
    # Are you sure you don't want to use Location Services?
    "<wait5s><tab><spacebar>",
    # Select Your Time Zone
    "<wait5s><tab>UTC<enter><leftShiftOn><tab><leftShiftOff><spacebar>",
    # Analytics
    "<wait5s><leftShiftOn><tab><leftShiftOff><spacebar>",
    # Screen Time
    "<wait5s><tab><spacebar>",
    # Siri
    "<wait5s><tab><spacebar><leftShiftOn><tab><leftShiftOff><spacebar>",
    # Choose Your Look
    "<wait5s><leftShiftOn><tab><leftShiftOff><spacebar>",
    # Enable Voice Over
    "<wait5s><leftAltOn><f5><leftAltOff><wait5s>v",
    # Now that the installation is done, open "System Settings"
    "<wait5s><leftAltOn><spacebar><leftAltOff>System Settings<enter>",
    # Navigate to "Sharing"
    "<wait5s><leftAltOn>f<leftAltOff>sharing<enter>",
    # Navigate to "Remote Login" and enable it
    "<wait5s><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><spacebar>",
    # Disable Voice Over
    "<leftAltOn><f5><leftAltOff>",
  ]

  // A (hopefully) temporary workaround for Virtualization.Framework's
  // installation process not fully finishing in a timely manner
  create_grace_time = "60s"
}

build {
  sources = ["source.tart-cli.tart"]

  provisioner "shell" {
    inline = [
      // Enable passwordless sudo
      "echo ${var.username} | sudo -S sh -c \"mkdir -p /etc/sudoers.d/; echo '${var.username} ALL=(ALL) NOPASSWD: ALL' | EDITOR=tee visudo /etc/sudoers.d/admin-nopasswd\"",
      // Enable auto-login
      //
      // See https://github.com/xfreebird/kcpassword for details.
      "echo '00000000: 19e0 2157 bbd0 b18f d1b9 1f' | sudo xxd -r - /etc/kcpassword",
      "sudo defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser ${var.username}",
      // Disable screensaver at login screen
      "sudo defaults write /Library/Preferences/com.apple.screensaver loginWindowIdleTime 0",
      // Disable screensaver for user
      "defaults -currentHost write com.apple.screensaver idleTime 0",
      // Prevent the VM from sleeping
      "sudo systemsetup -setdisplaysleep Off 2>/dev/null",
      "sudo systemsetup -setsleep Off 2>/dev/null",
      "sudo systemsetup -setcomputersleep Off 2>/dev/null",
      // Launch Safari to populate the defaults
      "/Applications/Safari.app/Contents/MacOS/Safari &",
      "SAFARI_PID=$!",
      "disown",
      "sleep 30",
      "kill -9 $SAFARI_PID",
      // Enable Safari's remote automation
      "sudo safaridriver --enable",
      // Disable screen lock
      //
      // Note that this only works if the user is logged-in,
      // i.e. not on login screen.
      "sysadminctl -screenLock off -password ${var.username}",
    ]
  }

  provisioner "file" {
    source      = "data/limit.maxfiles.plist"
    destination = "~/limit.maxfiles.plist"
  }
  provisioner "shell" {
    inline = [
      "mkdir -p ~/.ssh",
      "chmod 700 ~/.ssh"
    ]
  }
  provisioner "file" {
    source      = "data/config"
    destination = "~/.ssh/config"
  }

  provisioner "shell" {
    inline = [
      "echo 'Configuring maxfiles...'",
      "sudo mv ~/limit.maxfiles.plist /Library/LaunchDaemons/limit.maxfiles.plist",
      "sudo chown root:wheel /Library/LaunchDaemons/limit.maxfiles.plist",
      "sudo chmod 0644 /Library/LaunchDaemons/limit.maxfiles.plist",
      "echo 'Disabling spotlight...'",
      "sudo mdutil -a -i off",
    ]
  }
  # Create a symlink for bash compatibility
  provisioner "shell" {
    inline = [
      "touch ~/.zprofile",
      "ln -s ~/.zprofile ~/.profile",
    ]
  }
  provisioner "shell" {
    inline = [
      "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"",
      "echo \"export LANG=en_US.UTF-8\" >> ~/.zprofile",
      "echo 'eval \"$(/opt/homebrew/bin/brew shellenv)\"' >> ~/.zprofile",
      "echo \"export HOMEBREW_NO_AUTO_UPDATE=1\" >> ~/.zprofile",
      "echo \"export HOMEBREW_NO_INSTALL_CLEANUP=1\" >> ~/.zprofile",
      "source ~/.zprofile",
      "brew --version",
      "brew update",
      "brew install curl git git-lfs python@3.12 gnu-tar",
      "brew install --cask git-credential-manager",
      "git lfs install",
      "sudo softwareupdate --install-rosetta --agree-to-license"
    ]
  }
  provisioner "shell" {
    inline = [
      "source ~/.zprofile",
      "brew install openjdk@23",
      "echo 'export PATH=\"/opt/homebrew/opt/openjdk@23/bin:$PATH\"' >> ~/.zprofile",
    ]
  }
  provisioner "shell" {
    inline = [
      "source ~/.zprofile",
      "brew install libyaml", # https://github.com/rbenv/ruby-build/discussions/2118
      "brew install rbenv",
      "echo 'if which rbenv > /dev/null; then eval \"$(rbenv init -)\"; fi' >> ~/.zprofile",
      "source ~/.zprofile",
      "rbenv install 2.7.8", // latest 2.x.x before EOL
      "rbenv install -l | grep -v - | tail -2 | xargs -L1 rbenv install",
      "rbenv global $(rbenv install -l | grep -v - | tail -1)",
      "gem install bundler",
    ]
  }
  provisioner "shell" {
    inline = [
      "source ~/.zprofile",
      "brew install node@20",
      "echo 'export PATH=\"/opt/homebrew/opt/node@20/bin:$PATH\"' >> ~/.zprofile",
      "source ~/.zprofile",
      "node --version",
      "npm install --global yarn",
      "yarn --version",
    ]
  }
  provisioner "shell" {
    inline = [
      "source ~/.zprofile",
      "brew install awscli"
    ]
  }
  provisioner "shell" {
    inline = [
      "curl -so circleci-runner.tar.gz -L https://circleci-binary-releases.s3.amazonaws.com/circleci-runner/current/circleci-runner_darwin_arm64.tar.gz",
      "tar -xzf circleci-runner.tar.gz --directory ~/",
      "rm -f circleci-runner.tar.gz"
    ]
  }
  provisioner "shell" {
    inline = [
      "source ~/.zprofile",
      "brew install libimobiledevice ideviceinstaller ios-deploy fastlane carthage",
      "brew install xcbeautify",
      "gem update",
      "gem install cocoapods",
      "gem install xcpretty",
      "gem uninstall --ignore-dependencies ffi && gem install ffi -- --enable-libffi-alloc"
    ]
  }
  # inspired by https://github.com/actions/runner-images/blob/fb3b6fd69957772c1596848e2daaec69eabca1bb/images/macos/provision/configuration/configure-machine.sh#L33-L61
  provisioner "shell" {
    inline = [
      "source ~/.zprofile",
      "curl -o AppleWWDRCAG3.cer https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer",
      "curl -o DeveloperIDG2CA.cer https://www.apple.com/certificateauthority/DeveloperIDG2CA.cer",
      "curl -o add-certificate.swift https://raw.githubusercontent.com/actions/runner-images/fb3b6fd69957772c1596848e2daaec69eabca1bb/images/macos/provision/configuration/add-certificate.swift",
      "swiftc -suppress-warnings add-certificate.swift",
      "sudo ./add-certificate AppleWWDRCAG3.cer",
      "sudo ./add-certificate DeveloperIDG2CA.cer",
      "rm add-certificate* *.cer"
    ]
  }
  provisioner "shell" {
    inline = [
      "source ~/.zprofile",
      "brew install xcodesorg/made/xcodes",
      "xcodes version",
    ]
  }
  provisioner "file" {
    source      = pathexpand("~/Downloads/Xcode_${var.xcode_version}.xip")
    destination = "/Users/${var.username}/Downloads/"
  }
  provisioner "shell" {
    inline = [
      "source ~/.zprofile",
      "sudo xcodes install ${var.xcode_version} --experimental-unxip --path /Users/${var.username}/Downloads/Xcode_${var.xcode_version}.xip --select --empty-trash",
      // get selected xcode path, strip /Contents/Developer
      "INSTALLED_PATH=$(xcodes select -p)",
      "CONTENTS_DIR=$(dirname $INSTALLED_PATH)",
      "APP_DIR=$(dirname $CONTENTS_DIR)",
      "sudo mv $APP_DIR /Applications/Xcode_${var.xcode_version}.app",
      "sudo xcode-select -s /Applications/Xcode_${var.xcode_version}.app",
      "xcodebuild -downloadPlatform iOS",
      "xcodebuild -runFirstLaunch",
    ]
  }
  provisioner "shell" {
    inline = [
      "source ~/.zprofile",
      "sudo xcodes select '${var.xcode_version}'",
    ]
  }
  provisioner "shell" {
    inline = concat(
      ["source ~/.zprofile"],
      [
        for runtime in var.additional_runtimes : "sudo xcodes runtimes install ${runtime}"
      ]
    )
  }
  // check there is at least 15GB of free space and fail if not
  provisioner "shell" {
    inline = [
      "source ~/.zprofile",
      "df -h",
      "export FREE_MB=$(df -m | awk '{print $4}' | head -n 2 | tail -n 1)",
      "[[ $FREE_MB -gt ${var.disk_free_mb} ]] && echo OK || exit 1"
    ]
  }
}
