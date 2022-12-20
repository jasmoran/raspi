{ lib, pkgs, config, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];
  nixpkgs.crossSystem.system = "aarch64-linux";

  boot= {
    initrd.availableKernelModules = [ "usbhid" ];
    initrd.kernelModules = [ ];
    kernelModules = [ ];
    kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
    extraModulePackages = [ ];
    supportedFilesystems = [ "zfs" ];
    zfs.devNodes = "/dev/disk/by-id";
    loader = {
      efi.canTouchEfiVariables = true;
      grub = {
        enable = true;
        version = 2;
        efiSupport = true;
        device = "nodev";
        zfsSupport = true;
      };
    };
  };

  environment.etc."machine-id".source = "/state/etc/machine-id";
  environment.etc."zfs/zpool.cache".source = "/state/etc/zfs/zpool.cache";

  fileSystems = {
    "/" = {
      device = "zpool/root";
      fsType = "zfs";
      options = [ "zfsutil" "X-mount.mkdir" ];
    };
    "/boot" = {
      device = "/dev/disk/by-id/usb-WD_My_Passport_0748_575833314331323531313238-0:0-part1";
      fsType = "vfat";
    };
    "/root" = {
      device = "zpool/KEEP/root";
      fsType = "zfs";
      options = [ "zfsutil" "X-mount.mkdir" ];
    };
    "/nix" = {
      device = "zpool/KEEP/nix";
      fsType = "zfs";
      options = [ "zfsutil" "X-mount.mkdir" ];
    };
    "/state" = {
      device = "zpool/KEEP/state";
      fsType = "zfs";
      options = [ "zfsutil" "X-mount.mkdir" ];
      neededForBoot = true;
    };
    "/etc/nixos" = {
      device = "/state/etc/nixos";
      fsType = "none";
      options = [ "bind" ];
    };
    "/etc/cryptkey.d" = {
      device = "/state/etc/cryptkey.d";
      fsType = "none";
      options = [ "bind" ];
    };
    "/var/log" = {
      device = "/state/var/log";
      fsType = "none";
      options = [ "bind" ];
    };
  };

  swapDevices = [
    { device = "/dev/disk/by-id/usb-WD_My_Passport_0748_575833314331323531313238-0:0-part2"; }
  ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.eth0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlan0.useDHCP = lib.mkDefault true;

  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  networking.hostName = "raspi"; # Define your hostname.
  networking.hostId = "a6b2ef29";
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "Pacific/Auckland";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_NZ.UTF-8";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.root = {
    hashedPassword = "$6$SW2tM34VZem6TqkQ$yakLgWO.Rj/H3GcbnQR8jlhCAvAzMQ9WyqDMrrLUbVum//v5Mgyz.06KY/0OhSkRvTdHfptOWQiA0AKGoBLH..";
    openssh.authorizedKeys.keys = [ (builtins.readFile ./id_ed25519.pub) ];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    # cloudflared
  ];

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    openFirewall = true;
    passwordAuthentication = false;
    allowSFTP = false;
    kbdInteractiveAuthentication = false;
    extraConfig = ''
      AllowTcpForwarding yes
      X11Forwarding no
      AllowAgentForwarding no
      AllowStreamLocalForwarding no
      AuthenticationMethods publickey
    '';
  };

  services.xserver.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  system.copySystemConfiguration = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment?
}

