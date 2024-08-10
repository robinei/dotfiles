{ config, lib, pkgs, ... }:

{
  imports = [
    /etc/nixos/hardware-configuration.nix
    <home-manager/nixos>
  ];

  system.stateVersion = "24.05";
  system.copySystemConfiguration = true;
  nixpkgs.config.allowUnfree = true;

  fileSystems = {
    "/".options = ["compress-force=zstd:1" "noatime" ];
    "/home".options = ["compress-force=zstd:1" "noatime" ];
    "/nix".options = ["compress-force=zstd:1" "noatime" ];
    "/persist".options = ["compress-force=zstd:1" "noatime" ];
    "/persist".neededForBoot = true;
    "/var/log".options = ["compress-force=zstd:1" "noatime" ];
    "/var/log".neededForBoot = true;
    "/mnt/old" = {
      device = "/dev/sda3";
      fsType = "ext4";
    };
  };

  boot = {
    initrd.kernelModules = [ "amdgpu" ];
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    kernelPackages = pkgs.linuxPackages_zen;
    kernelParams = ["drm.edid_firmware=edid/edid.bin"];
    extraModprobeConfig = ''
      blacklist uvcvideo
      blacklist pcspkr
      options usbhid mousepoll=8
    '';
  };
  
  #hardware.graphics.driSupport32Bit = true;
  hardware.enableAllFirmware = true;
  hardware.firmware = [
    (pkgs.runCommandNoCC "edid.bin" { compressFirmware = false; } ''
      mkdir -p $out/lib/firmware/edid/
      cp ${./files/edid.bin} $out/lib/firmware/edid/edid.bin
    '')
  ];

  networking.hostName = "laptop";
  networking.networkmanager.enable = true;
  #networking.firewall.allowedTCPPorts = [ ... ];
  #networking.firewall.allowedUDPPorts = [ ... ];

  time.timeZone = "Europe/Oslo";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    earlySetup = true;
    font = "Lat2-Terminus16";
    keyMap = "no";
  };

  environment.variables = {
    EDITOR = "vim";
  };

  users.mutableUsers = false;
  users.users.robin = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "audio" "video" "input" ];
    hashedPasswordFile = "/persist/passwords/robin";
  };

  powerManagement = {
    enable = true;
    powertop.enable = true;
    cpuFreqGovernor = "schedutil";
  };

  xdg.portal = {
    wlr.enable = true;
    config.common.default = "*";
    extraPortals = [ pkgs.xdg-desktop-portal-wlr pkgs.xdg-desktop-portal-gtk ];
    xdgOpenUsePortal = true;
  };
  
  services = {
    udisks2.enable = true;
    devmon.enable = true;
    flatpak.enable = true;

    locate = {
      enable = true;
      package = pkgs.plocate;
      localuser = null;
    };

    udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="input", TEST=="power/control", ATTR{power/control}="on"
    '';

    xserver = {
      enable = true;
      videoDrivers = [ "amdgpu" ];
      xkb.layout = "no";
      xkb.options = "ctrl:nocaps";
    };

    dbus.enable = true;
    dbus.implementation = "broker";

    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      jack.enable = true;
      wireplumber.enable = true;
    };

    greetd = {
      enable = true;
      settings = rec {
        initial_session = {
          #command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd sway";
          #command = "${pkgs.sway}/bin/sway";
          command = "dbus-run-session sway -D noscanout";
          user = "robin";
        };
        default_session = initial_session;
      };
    };
  };
  
  security.rtkit.enable = true;
  security.polkit.enable = true;
  
  programs.light.enable = true;
  programs.dconf.enable = true;

  environment.systemPackages = with pkgs; [
    file
    htop
    powertop
    neofetch
    sutils
    vim
    wget
    curl
    killall
    jq
    p7zip
    rar
    unzip
    cifs-utils
    pulseaudio
    adwaita-icon-theme
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.robin = { pkgs, ... }: {
    home.stateVersion = "24.05";
    
    home.packages = with pkgs; [
      libnotify
      wl-clipboard
      wmenu
      dmenu
      mako
      udiskie
      pcmanfm
      dolphin
      font-awesome_5
      mprime
      vrrtest
    ];
    
    home.file = {
      ".vimrc".source = ./files/.vimrc;
      ".emacs".source = ./files/.emacs;
    };

    programs.git = {
      enable = true;
      package = pkgs.gitAndTools.gitFull;
      userName = "Robin Eidissen";
      userEmail = "robinei@gmail.com";
      extraConfig = {
        core.editor = "vim";
        credential.helper = "cache";
      };
    };

    xdg = {
      enable = true;
      mime.enable = true;
      mimeApps = {
        enable = true;
        defaultApplications = {
          #"application/pdf" = ["evince.desktop"];
          "inode/directory" = ["pcmanfm.desktop"];
          "text/html" = "firefox.desktop";
          "application/xhtml+xml" = "firefox.desktop";
          "x-scheme-handler/chrome" = "firefox.desktop";
          "x-scheme-handler/http" = "firefox.desktop";
          "x-scheme-handler/https" = "firefox.desktop";
        };
      };
      userDirs = {
        enable = true;
        createDirectories = true;
      };
    };

    gtk = {
      enable = true;
      #font.name = "Victor Mono SemiBold 12";
      theme = {
        name = "Adwaita-dark";
        package = pkgs.gnome-themes-extra;
      };
    };

    qt = {
      enable = true;
      platformTheme.name = "adwaita";
      style = {
        name = "adwaita-dark";
        package = pkgs.adwaita-qt;
      };
    };
    
    programs.waybar = {
      enable = true;
      #systemd.enable = true;
      style = "${./files/waybar/style.css}";
    };
    xdg.configFile."waybar/config" = {
      source = "${./files/waybar/config}";
      onChange = "${pkgs.procps}/bin/pkill -u $USER -USR2 waybar || true";
    };

    services.udiskie = {
      enable = true;
      settings = {
        tray = "always";
      };
    };

    wayland.windowManager.sway = let
      bg = "#171717e0";
      fg = "#ffffffe0";
      br = "#323232e0";
      ia = "#ffffffe0";
      bk = "#000000e0";
    in {
      enable = true;
      systemd.enable = true;
      wrapperFeatures.gtk = true;
      config = rec {
        modifier = "Mod4";
        terminal = "foot";
        menu = "dmenu_path | wmenu -p 'Run:' -f 'DejaVu Sans 13' -N '#000000' -n '#808080' -s '#ffffff' -m '#ffffff' | xargs swaymsg exec --";
        defaultWorkspace = "1";
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
        bindsym XF86MonBrightnessDown exec light -U 10
        bindsym XF86MonBrightnessUp exec light -A 10
        bindsym XF86AudioRaiseVolume exec 'pactl set-sink-volume @DEFAULT_SINK@ +1%'
        bindsym XF86AudioLowerVolume exec 'pactl set-sink-volume @DEFAULT_SINK@ -1%'
        bindsym XF86AudioMute exec 'pactl set-sink-mute @DEFAULT_SINK@ toggle'
        bindsym XF86AudioMicMute exec 'pactl set-source-mute @DEFAULT_SOURCE@ toggle'
        output * bg ${./files/stars.jpg} fill
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
        exec wl-paste -t text --watch clipman store --no-persist
        exec mako --background-color=${bg} --text-color=${fg} --border-color=${fg} --default-timeout=10000 --markup=1 --actions=1 --icons=1
      '';
    };

    programs.foot = {
      enable = true;
      settings = {
        main = {
          font = "monospace:size=9";
          selection-target = "both";
        };
        colors = {
          alpha = 0.92;
          foreground = "ffffff";
          background = "000000";
        };
        scrollback.lines = 10000;
      };
    };

    programs.firefox.enable = true;
    programs.emacs.enable = true;
    programs.vscode.enable = true;
  };
}

