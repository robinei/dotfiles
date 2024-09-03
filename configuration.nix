{ config, lib, pkgs, ... }:

{
  imports = [
    /etc/nixos/hardware-configuration.nix
    <home-manager/nixos>
  ];

  system.stateVersion = "24.05";
  system.copySystemConfiguration = true;
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
    (nerdfonts.override { fonts = [ "EnvyCodeR" ]; })
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

  systemd.services = {
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
      localuser = null;
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

  environment.etc."current-system-packages".text =
  let
    packages = builtins.map (p: "${p.name}") config.environment.systemPackages;
    sortedUnique = builtins.sort builtins.lessThan (pkgs.lib.lists.unique packages);
    formatted = builtins.concatStringsSep "\n" sortedUnique;
  in
    formatted;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.robin = { config, pkgs, ... }: let
    terminal = "foot";
    dotfilesDir = "${config.home.homeDirectory}/Config";
  in {
    home.stateVersion = "24.05";
    
    home.packages = with pkgs; [
      # system utils
      clipman
      wl-clipboard
      libnotify
      mako
      udiskie
      brightnessctl
      grim # screenshot
      slurp # region selection

      # applications
      pavucontrol
      swayimg
      gimp
      (calibre.override { unrarSupport = true; })

      # development
      direnv
      nil # nix language server
      rust-analyzer
      typescript-language-server
      python312Packages.python-lsp-server
      bun
      fzf
      ripgrep
      zed-editor

      # gameutils/monitoring/performance
      mprime
      vrrtest
      gamescope
      mangohud
      protontricks

      # games
      arx-libertatis
      cdogs-sdl
      exult
      fheroes2
      openttd
      openrct2
      openxcom
      openra
      openmw
      corsix-th
      devilutionx

      # "emulators"
      wine
      scummvm
      dosbox-staging
      dolphin-emu
      ppsspp
      (retroarch.override {
        cores = with libretro; [
          mgba
          snes9x
        ];
      })

      # scripts
      (pkgs.writeShellScriptBin "steamlite" ''
        #!/usr/bin/env sh
        exec steam -nofriendsui -no-browser +open "steam://open/minigameslist" 
      '')
      (pkgs.writeShellScriptBin "yazi-run" ''
        #!/usr/bin/env sh
        if [ "$TERM" == "${terminal}" ]; then
          exec yazi "$@"
        else
          exec ${terminal} -e yazi "$@"
        fi
      '')
      (pkgs.writeShellScriptBin "toggleboost" ''
        #!/usr/bin/env sh
        if grep -q 0 /sys/devices/system/cpu/cpufreq/boost; then 
          echo "1" | sudo tee /sys/devices/system/cpu/cpufreq/boost
        else
          echo "0" | sudo tee /sys/devices/system/cpu/cpufreq/boost
        fi
      '')
    ];

    programs.emacs.enable = true;
    programs.vscode.enable = true;
    programs.zathura.enable = true;
    programs.firefox.enable = true;

    programs.fuzzel = {
      enable = true;
      settings = {
        main = {
          inherit terminal;
          font = "monospace:size=8";
          fields = "filename,name,categories";
          lines = 40;
          width = 60;
        };
        colors = {
          background = "1e1e2edd";
          text = "cdd6f4ff";
          match = "89b4faff";
          selection = "585b70ff";
          selection-match = "89b4faff";
          selection-text = "cdd6f4ff";
          border = "b4befeff";
        };
      };
    };

    home.sessionVariables = rec {
      EDITOR = "hx";
      BROWSER = "firefox";
      DEFAULT_BROWSER = BROWSER;
      MANGOHUD_CONFIG = "read_cfg,cpu_mhz,cpu_temp,cpu_power,gpu_temp,gpu_power,gpu_core_clock,fan,battery,round_corners=5.0,font_scale=0.6,alpha=0.6,background_alpha=0.5,gpu_load_change,cpu_load_change,gpu_load_color=FFFFFF+FFFFFF+FF9900,gpu_load_value=50+85,cpu_load_color=FFFFFF+FFFFFF+FF9900,cpu_load_value=65+85,frametime_color=888888,text_color=BDBDBD,gpu_color=00E5E5,cpu_color=00E5E5,vram_color=00E5E5,ram_color=00E5E5,engine_color=00E5E5,battery_color=00E5E5,offset_x=-10,offset_y=-10";
      GTK_THEME = "Adwaita:dark";
    };
    #systemd.user.sessionVariables = config.home.sessionVariables;
    
    programs.git = {
      enable = true;
      package = pkgs.gitAndTools.gitFull;
      userName = "Robin Eidissen";
      userEmail = "robinei@gmail.com";
      extraConfig = {
        core.editor = "hx";
        credential.helper = "cache";
      };
    };

    xdg = {
      enable = true;
      desktopEntries = let hidden = { name = "Hidden"; exec = "true"; noDisplay = true; }; in
      {
        "org.codeberg.dnkl.foot-server" = hidden;
        "org.codeberg.dnkl.footclient" = hidden;
        "emacsclient" = hidden;
        "fish" = hidden;
        "yazi" = {
          name = "Yazi";
          icon = "yazi";
          exec = "yazi-run";
          categories = ["System"];
          mimeType = ["inode/directory"];
        };
        "steamlite" = {
          name = "Steam Lite";
          icon = "steam";
          exec = "steamlite";
          categories = ["Game"];
        };
      };
      mimeApps = {
        enable = true;
        defaultApplications = {
          "inode/directory"         = "yazi.desktop";
          "text/html"               = "firefox.desktop";
          "text/xml"                = "firefox.desktop";
          "application/xhtml+xml"   = "firefox.desktop";
          "x-scheme-handler/http"   = "firefox.desktop";
          "x-scheme-handler/https"  = "firefox.desktop";
          "application/pdf"         = "org.pwmt.zathura.desktop";
          "image/jpeg"              = "swayimg.desktop";
          "image/png"               = "swayimg.desktop";
        };
        associations.removed = {};
        associations.added = {};
      };
      userDirs = {
        enable = true;
        createDirectories = true;
      };
    };

    qt = {
      enable = true;
      platformTheme.name = "adwaita";
      style = {
        name = "adwaita-dark";
      };
    };

    gtk = {
      enable = true;
      theme = {
        name = "Adwaita-dark";
        package = pkgs.gnome-themes-extra;
      };
      iconTheme = {
        name = "Adwaita";
        package = pkgs.adwaita-icon-theme;
      };
      gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
      gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
    };

    dconf = {
      enable = true;
      settings = {
        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
        };
      };
    };
    
    programs.waybar = {
      enable = true;
      style = "${./files/waybar/style.css}";
    };
    xdg.configFile."waybar/config" = {
      source = "${./files/waybar/config}";
      onChange = "${pkgs.procps}/bin/pkill -u $USER -USR2 waybar || true";
    };

    wayland.windowManager.sway = let
      modifier = "Mod4";
      bg = "#171717e0";
      fg = "#ffffffe0";
      br = "#323232e0";
      ia = "#ffffffe0";
      bk = "#000000e0";
      startupScript = builtins.toFile "startup.sh" ''
        #systemctl --user import-environment DISPLAY WAYLAND_DISPLAY SWAYSOCK
        uwsm finalize

        wl-paste -t text --watch clipman store --no-persist &
        mako --background-color=#171717e0 --text-color=#ffffffe0 --border-color=#ffffffe0 --default-timeout=10000 --markup=1 --actions=1 --icons=1 &
        udiskie --notify --automount --tray --appindicator --file-manager yazi-run &
        blueman-applet &
        wait
      '';
    in {
      enable = true;
      wrapperFeatures.gtk = true;
      config = {
        inherit modifier terminal;
        menu = "fuzzel --list-executables-in-path";
        defaultWorkspace = "workspace number 1";
        focus.followMouse = false;
        colors = {
          focused =         { border = br; background = br; text = fg; indicator = ia; childBorder = br; };
          focusedInactive = { border = bg; background = bg; text = fg; indicator = ia; childBorder = bk; };
          unfocused =       { border = bg; background = bg; text = fg; indicator = ia; childBorder = bk; };
        };
        bars = [{
          command = "waybar";
          position = "top";
        }];
      };
      extraConfig = ''
        default_border pixel 1
        default_floating_border normal 1
        bindsym ${modifier}+p exec yazi-run
        bindsym ${modifier}+m exec fuzzel
        bindsym ${modifier}+Backspace kill
        bindsym XF86MonBrightnessDown exec brightnessctl set 5%-
        bindsym XF86MonBrightnessUp exec brightnessctl set 5%+
        bindsym XF86AudioRaiseVolume exec 'pactl set-sink-volume @DEFAULT_SINK@ +1%'
        bindsym XF86AudioLowerVolume exec 'pactl set-sink-volume @DEFAULT_SINK@ -1%'
        bindsym XF86AudioMute exec 'pactl set-sink-mute @DEFAULT_SINK@ toggle'
        bindsym XF86AudioMicMute exec 'pactl set-source-mute @DEFAULT_SOURCE@ toggle'
        bindsym Print exec 'grim - | wl-copy'
        bindsym Shift+Print exec 'grim -g "$(slurp)" - | wl-copy'
        output * bg ${./files/wallpaper.jpg} fill
        output * adaptive_sync on
        input type:keyboard {
          xkb_layout "no"
          xkb_options "ctrl:nocaps"
        }
        input type:pointer {
          accel_profile flat
          pointer_accel 0
        }
        input type:touchpad {
          dwt disabled
          tap enabled
          natural_scroll enabled
          tap_button_map lrm
          click_method clickfinger
        }
        exec sh ${startupScript}
      '';
    };

    programs.yazi = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        manager.linemode = "mtime";
        opener.edit = [{ run = ''hx "$@"''; block = true; }];
        opener.open = [{ run = ''xdg-open "$@"''; }];
        open.append_rules = [
          { mime = "inode/directory"; use = "edit"; }
          { mime = "text/*"; use = "edit"; }
          { mime = "*"; use = "open"; }
        ];
      };
      keymap = {
        manager.prepend_keymap = [
          { on = "<C-s>"; run  = ''shell fish --block --confirm''; desc = "Open shell here"; }
          #{ on = "<Esc>"; run = "close"; desc = "Cancel input"; }
          #{ on = "y"; run = [''shell 'for path in "$@"; do echo "file://$path"; done | wl-copy -t text/uri-list' --confirm'' "yank"]; desc = "Yank"; }
        ];
      };
    };

    programs.helix = {
      enable = true;
      settings = {
        theme = "ayu_evolve";
        editor = {
          cursorline = true;
        };
      };
    };

    programs.fish = let startwm = "systemd-cat -t uwsm_start uwsm start -- /etc/profiles/per-user/robin/bin/sway -D noscanout"; in {
      enable = true;
      interactiveShellInit = ''
        set fish_greeting
        direnv hook fish | source
        source (fzf-share)/key-bindings.fish
        fzf_key_bindings
        if uwsm check may-start;
          ${startwm}
        end
      '';
      shellAliases = {
        lsapps = "ls -l ~/.local/share/applications /run/current-system/sw/share/applications /etc/profiles/per-user/robin/share/applications";
        nixbuild = "sudo nixos-rebuild switch -I nixos-config=${dotfilesDir}/configuration.nix";
        nixupgrade = "sudo nixos-rebuild switch --upgrade -I nixos-config=${dotfilesDir}/configuration.nix";
        nixdiff = "nix profile diff-closures --profile /nix/var/nix/profiles/system --extra-experimental-features nix-command";
        nixgc = "sudo nix-collect-garbage --delete-older-than 2d && sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";
        wm = startwm;
      };
    };

    programs.foot = {
      enable = true;
      settings = {
        main = rec {
          shell = "fish";
          font = "EnvyCodeR Nerd Font:size=10";
          font-bold = font;
          font-italic = font;
          selection-target = "both";
          bold-text-in-bright = true;
        };
        colors = {
          alpha = 0.92;
          foreground = "ffffff";
          background = "000000";
        };
        scrollback.lines = 10000;
      };
    };

    home.file = {
      #".vimrc".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/files/.vimrc";
      ".emacs".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/files/.emacs";
    };
  };
}

