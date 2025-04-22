{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  system.stateVersion = "24.05";
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];

  fileSystems = {
    "/".options = ["compress-force=zstd:1" "noatime" ];
    "/home".options = ["compress-force=zstd:1" "noatime" ];
    "/nix".options = ["compress-force=zstd:1" "noatime" ];
    "/persist".options = ["compress-force=zstd:1" "noatime" ];
    "/persist".neededForBoot = true;
    "/var/log".options = ["compress-force=zstd:1" "noatime" ];
    "/var/log".neededForBoot = true;
    #"/mnt/old" = { device = "/dev/sda3"; fsType = "ext4"; };
  };

  boot = {
    initrd.kernelModules = [ "amdgpu" ];
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    kernelPackages = pkgs.linuxPackages_zen;
    kernelParams = ["drm.edid_firmware=edid/edid.bin" "mitigations=off"];
    extraModprobeConfig = ''
      blacklist uvcvideo
      blacklist pcspkr
      options usbhid mousepoll=8
    '';
  };
  
  hardware = {
    bluetooth.enable = true;
    #bluetooth.powerOnBoot = true;
    enableAllFirmware = true;
    firmware = [
      (pkgs.runCommandNoCC "edid.bin" { compressFirmware = false; } ''
        mkdir -p $out/lib/firmware/edid/
        cp ${./files/edid.bin} $out/lib/firmware/edid/edid.bin
      '')
    ];
  };

  networking.hostName = "laptop";
  networking.networkmanager.enable = true;
  #networking.firewall.allowedTCPPorts = [];
  #networking.firewall.allowedUDPPorts = [];

  time.timeZone = "Europe/Oslo";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    earlySetup = true;
    font = "Lat2-Terminus16";
    keyMap = "no";
  };

  fonts.packages = with pkgs; [
    ttf-envy-code-r
    font-awesome_5
    nerd-fonts.envy-code-r
  ];

  users.mutableUsers = false;
  users.users.robin = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "audio" "video" "input" ];
    hashedPasswordFile = "/persist/passwords/robin";
    shell = pkgs.fish;
  };

  powerManagement = {
    enable = true;
    cpuFreqGovernor = "schedutil";
  };

  xdg.portal = {
    wlr.enable = true;
    config.common.default = "*";
    extraPortals = [
      pkgs.xdg-desktop-portal-wlr
      pkgs.xdg-desktop-portal-gtk
    ];
    #xdgOpenUsePortal = true; # does not respect host mimeapps: https://github.com/flatpak/xdg-desktop-portal-gtk/issues/436
  };

  systemd = {
    user.services.polkit-gnome-authentication-agent-1 = {
      description = "polkit-gnome-authentication-agent-1";
      wantedBy = [ "graphical-session.target" ];
      wants = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
          Restart = "on-failure";
          RestartSec = 1;
          TimeoutStopSec = 10;
        };
    };

    services = {
      NetworkManager-wait-online.enable = false;
    
      "getty@tty1" = {
        overrideStrategy = "asDropin";
        serviceConfig.ExecStart = ["" "@${pkgs.util-linux}/sbin/agetty agetty --login-program ${config.services.getty.loginProgram} --autologin robin --noclear --keep-baud %I 115200,38400,9600 $TERM"];
        serviceConfig.TTYVTDisallocate = false;
      };
    
      powertune = let powertune-script = pkgs.writeShellScript "powertune.sh" ''
            echo '1500' > '/proc/sys/vm/dirty_writeback_centisecs'; # VM writeback timeout
            echo '1' > '/sys/module/snd_hda_intel/parameters/power_save'; # Enable Audio codec power management
            echo '0' > '/proc/sys/kernel/nmi_watchdog'; # NMI watchdog should be turned off
            echo 'auto' > '/sys/bus/i2c/devices/i2c-7/device/power/control'; # Runtime PM for I2C Adapter i2c-7 (SMBus PIIX4 adapter port 0 at 0b00)
            echo 'auto' > '/sys/bus/i2c/devices/i2c-9/device/power/control'; # Runtime PM for I2C Adapter i2c-9 (SMBus PIIX4 adapter port 1 at 0b20)
            echo 'auto' > '/sys/bus/i2c/devices/i2c-2/device/power/control'; # Runtime PM for I2C Adapter i2c-2 (AMDGPU DM i2c hw bus 0)
            echo 'auto' > '/sys/bus/i2c/devices/i2c-3/device/power/control'; # Runtime PM for I2C Adapter i2c-3 (AMDGPU DM i2c hw bus 1)
            echo 'auto' > '/sys/bus/i2c/devices/i2c-4/device/power/control'; # Runtime PM for I2C Adapter i2c-4 (AMDGPU DM i2c hw bus 2)
            echo 'auto' > '/sys/bus/usb/devices/1-3/power/control'; # Autosuspend for USB device Integrated Camera [Azurewave]
            echo 'auto' > '/sys/bus/i2c/devices/i2c-8/device/power/control'; # Runtime PM for I2C Adapter i2c-8 (SMBus PIIX4 adapter port 2 at 0b00)
            echo 'auto' > '/sys/bus/pci/devices/0000:03:00.3/power/control'; # Runtime PM for PCI Device Advanced Micro Devices, Inc. [AMD] Renoir/Cezanne USB 3.1
            echo 'auto' > '/sys/bus/pci/devices/0000:04:00.1/ata2/power/control'; # Runtime PM for port ata2 of PCI device: Advanced Micro Devices, Inc. [AMD] FCH SATA Controller [AHCI mode]
            echo 'auto' > '/sys/bus/pci/devices/0000:01:00.0/power/control'; # Runtime PM for PCI Device Intel Corporation Wi-Fi 6 AX200
            echo 'auto' > '/sys/bus/pci/devices/0000:04:00.1/power/control'; # Runtime PM for PCI Device Advanced Micro Devices, Inc. [AMD] FCH SATA Controller [AHCI mode]
            echo 'auto' > '/sys/bus/pci/devices/0000:00:14.3/power/control'; # Runtime PM for PCI Device Advanced Micro Devices, Inc. [AMD] FCH LPC Bridge
            echo 'auto' > '/sys/bus/pci/devices/0000:03:00.5/power/control'; # Runtime PM for PCI Device Advanced Micro Devices, Inc. [AMD] ACP/ACP3X/ACP6x Audio Coprocessor
            echo 'auto' > '/sys/bus/pci/devices/0000:00:01.0/power/control'; # Runtime PM for PCI Device Advanced Micro Devices, Inc. [AMD] Renoir PCIe Dummy Host Bridge
            echo 'auto' > '/sys/bus/pci/devices/0000:02:00.0/power/control'; # Runtime PM for PCI Device Micron Technology Inc 2550 NVMe SSD (DRAM-less)
            echo 'auto' > '/sys/bus/pci/devices/0000:00:18.1/power/control'; # Runtime PM for PCI Device Advanced Micro Devices, Inc. [AMD] Renoir Device 24: Function 1
            echo 'auto' > '/sys/bus/pci/devices/0000:00:18.3/power/control'; # Runtime PM for PCI Device Advanced Micro Devices, Inc. [AMD] Renoir Device 24: Function 3
            echo 'auto' > '/sys/bus/pci/devices/0000:00:08.0/power/control'; # Runtime PM for PCI Device Advanced Micro Devices, Inc. [AMD] Renoir PCIe Dummy Host Bridge
            echo 'auto' > '/sys/bus/pci/devices/0000:04:00.0/ata1/power/control'; # Runtime PM for port ata1 of PCI device: Advanced Micro Devices, Inc. [AMD] FCH SATA Controller [AHCI mode]
            echo 'auto' > '/sys/bus/pci/devices/0000:03:00.0/power/control'; # Runtime PM for PCI Device Advanced Micro Devices, Inc. [AMD/ATI] Renoir [Radeon Vega Series / Radeon Vega Mobile Series]
            echo 'auto' > '/sys/bus/pci/devices/0000:00:18.6/power/control'; # Runtime PM for PCI Device Advanced Micro Devices, Inc. [AMD] Renoir Device 24: Function 6
            echo 'auto' > '/sys/bus/pci/devices/0000:00:00.0/power/control'; # Runtime PM for PCI Device Advanced Micro Devices, Inc. [AMD] Renoir/Cezanne Root Complex
            echo 'auto' > '/sys/bus/pci/devices/0000:00:18.4/power/control'; # Runtime PM for PCI Device Advanced Micro Devices, Inc. [AMD] Renoir Device 24: Function 4
            echo 'auto' > '/sys/bus/pci/devices/0000:00:18.5/power/control'; # Runtime PM for PCI Device Advanced Micro Devices, Inc. [AMD] Renoir Device 24: Function 5
            echo 'auto' > '/sys/bus/pci/devices/0000:00:18.2/power/control'; # Runtime PM for PCI Device Advanced Micro Devices, Inc. [AMD] Renoir Device 24: Function 2
            echo 'auto' > '/sys/bus/pci/devices/0000:00:14.0/power/control'; # Runtime PM for PCI Device Advanced Micro Devices, Inc. [AMD] FCH SMBus Controller
            echo 'auto' > '/sys/bus/pci/devices/0000:00:18.0/power/control'; # Runtime PM for PCI Device Advanced Micro Devices, Inc. [AMD] Renoir Device 24: Function 0
            echo 'auto' > '/sys/bus/pci/devices/0000:03:00.2/power/control'; # Runtime PM for PCI Device Advanced Micro Devices, Inc. [AMD] Family 17h (Models 10h-1fh) Platform Security Processor
            echo 'auto' > '/sys/bus/pci/devices/0000:00:18.7/power/control'; # Runtime PM for PCI Device Advanced Micro Devices, Inc. [AMD] Renoir Device 24: Function 7
            echo 'auto' > '/sys/bus/pci/devices/0000:03:00.4/power/control'; # Runtime PM for PCI Device Advanced Micro Devices, Inc. [AMD] Renoir/Cezanne USB 3.1
            echo 'auto' > '/sys/bus/pci/devices/0000:04:00.0/power/control'; # Runtime PM for PCI Device Advanced Micro Devices, Inc. [AMD] FCH SATA Controller [AHCI mode]
            echo 'auto' > '/sys/bus/pci/devices/0000:00:02.0/power/control'; # Runtime PM for PCI Device Advanced Micro Devices, Inc. [AMD] Renoir PCIe Dummy Host Bridge
            echo 'auto' > '/sys/bus/pci/devices/0000:00:00.2/power/control';  # Runtime PM for PCI Device Advanced Micro Devices, Inc. [AMD] Renoir/Cezanne IOMMU
          '';
      in {
        enable = true;
        description = "Apply powertop suggested tunings";
        unitConfig = {
          Type = "simple";
        };
        serviceConfig = {
          User = "root";
          Group = "root";
          ExecStart = "${powertune-script}";
        };
        wantedBy = [ "multi-user.target" ];
      };
    };
  };
  
  services = {
    udisks2.enable = true;
    upower.enable = true;
    devmon.enable = true;
    flatpak.enable = true;
    blueman.enable = true;
    dbus.enable = true;
    dbus.implementation = "broker";
    speechd.enable = lib.mkForce false;

    locate = {
      enable = true;
      package = pkgs.plocate;
    };

    xserver = {
      enable = true;
      videoDrivers = [ "amdgpu" ];
      xkb.layout = "no";
      xkb.options = "ctrl:nocaps";
      excludePackages = [ pkgs.xterm ];
      displayManager.startx.enable = true; # disables display manager
    };

    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };
  };

  qt = {
    enable = true;
    style = "adwaita-dark";
  };
  
  security.rtkit.enable = true;
  security.polkit.enable = true;
  
  programs.ssh.startAgent = true;
  programs.fish.enable = true;
  programs.dconf.enable = true;
  programs.steam.enable = true;

  environment.systemPackages = with pkgs; [
    # system tools
    duperemove # btrfs dedup
    usbutils
    pciutils
    smartmontools
    powertop
    lm_sensors
    killall
    htop
    btop
    polkit_gnome

    # misc tools
    file
    python3
    wget
    curl
    jq
    ouch # compression/decompression
    trashy # trash can manager
    cifs-utils # for mounting samba shares
    pulseaudio # for pavucontrol
    sutils # for clock
    uwsm
  ];
}
