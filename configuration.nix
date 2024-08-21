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
  };

  powerManagement = {
    enable = true;
    powertop.enable = true;
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
  
  services = {
    udisks2.enable = true;
    devmon.enable = true;
    flatpak.enable = true;
    blueman.enable = true;
    dbus.enable = true;
    dbus.implementation = "broker";

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
    };

    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };

    greetd = {
      enable = true;
      settings = rec {
        initial_session = {
          #command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd sway -D noscanout";
          command = "dbus-run-session sway -D noscanout";
          user = "robin";
        };
        default_session = initial_session;
      };
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
  programs.light.enable = true;
  programs.dconf.enable = true;
  programs.steam.enable = true;

  environment.systemPackages = with pkgs; [
    duperemove
    file
    htop
    usbutils
    pciutils
    powertop
    lm_sensors
    sutils # for clock
    python3
    wget
    curl
    killall
    jq
    ouch
    trashy
    cifs-utils
    samba
    pulseaudio
  ];

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

      # applications
      pavucontrol
      swayimg
      (calibre.override { unrarSupport = true; })

      # development
      nil # nix language server
      rust-analyzer
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
        systemctl --user import-environment DISPLAY WAYLAND_DISPLAY SWAYSOCK

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
        bindsym XF86MonBrightnessDown exec light -U 10
        bindsym XF86MonBrightnessUp exec light -A 10
        bindsym XF86AudioRaiseVolume exec 'pactl set-sink-volume @DEFAULT_SINK@ +1%'
        bindsym XF86AudioLowerVolume exec 'pactl set-sink-volume @DEFAULT_SINK@ -1%'
        bindsym XF86AudioMute exec 'pactl set-sink-mute @DEFAULT_SINK@ toggle'
        bindsym XF86AudioMicMute exec 'pactl set-source-mute @DEFAULT_SOURCE@ toggle'
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
        opener.edit = [{ run = ''hx "$@"''; block = true; }];
        opener.open = [{ run = ''xdg-open "$@"''; }];
        open.append_rules = [
          { mime = "inode/directory"; use = "edit"; }
          { mime = "text/*"; use = "edit"; }
          { mime = "*"; use = "open"; }
        ];
        manager.prepend_keymap = [
          { on = "<C-s>"; run  = ''shell "$SHELL" --block --confirm''; desc = "Open shell here"; }
          { on = "<Esc>"; run = "close"; desc = "Cancel input"; }
          { on = "l"; run = "plugin --sync smart-enter"; desc = "Enter the child directory, or open the file"; }
        ];
      };
      plugins = {
        smart-enter = ./files/yazi/plugins/smart-enter.yazi;
      };
    };

    programs.helix = {
      enable = true;
      settings = {
        theme = "dracula_at_night";
        editor = {
          cursorline = true;
        };
      };
    };

    programs.fish = {
      enable = true;
      interactiveShellInit = ''
        set fish_greeting
        source (fzf-share)/key-bindings.fish
        fzf_key_bindings
      '';
      shellAliases = {
        lsapps = "ls -l .local/share/applications /run/current-system/sw/share/applications /etc/profiles/per-user/robin/share/applications";
        nixbuild = "sudo nixos-rebuild switch -I nixos-config=${dotfilesDir}/configuration.nix";
        nixupgrade = "sudo nixos-rebuild switch --upgrade -I nixos-config=${dotfilesDir}/configuration.nix";
        nixdiff = "nix profile diff-closures --profile /nix/var/nix/profiles/system --extra-experimental-features nix-command";
        nixgc = "sudo nix-collect-garbage --delete-older-than 2d && sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";
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

