# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
  boot.loader.grub.enable = false;
  # Enables the generation of /boot/extlinux/extlinux.conf
  boot.loader.generic-extlinux-compatible.enable = true;

  networking.hostName = "raspi"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "Pacific/Auckland";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_NZ.UTF-8";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.jack = {
    description = "Jack Moran";
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    hashedPassword = "$6$SW2tM34VZem6TqkQ$yakLgWO.Rj/H3GcbnQR8jlhCAvAzMQ9WyqDMrrLUbVum//v5Mgyz.06KY/0OhSkRvTdHfptOWQiA0AKGoBLH..";
    openssh.authorizedKeys.keys = [ (builtins.readFile ./ca-bundle.crt) ];
  };

  users.users.cloudflared = {
    group = "cloudflared";
    isSystemUser = true;
  };
  users.groups.cloudflared = { };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    cloudflared
  ];

  systemd.services.cloudflare_tunnel = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "systemd-resolved.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token=eyJhIjoiNmI0ZjRiOTllMWZjYTFjNGRjMzMyMjQwOWYwNGU5NzkiLCJ0IjoiZjllNmFmYWQtYjhjMS00MWE5LWJjZWUtZjlmYmI0MjBkYWFiIiwicyI6Ill6WXhNekZtT1RNdE1EWmlNaTAwTW1abExUa3lZemt0TTJRNFpEVmhZekJsTlRnMCJ9";
      Restart = "always";
      User = "cloudflared";
      Group = "cloudflared";
    };
  };

  services.caddy = {
    enable = false;
    email = "jack@earth.co.nz";
    config =
      ''
        raspi.earth.co.nz
        respond "Hello Caddy!"
      '';
  };

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    openFirewall = false;
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

  # Enable the tailscale service
  services.tailscale.enable = true;

  networking.firewall = {
    # enable the firewall
    enable = false;

    # always allow traffic from your Tailscale network
    trustedInterfaces = [ "tailscale0" ];

    # allow the Tailscale UDP port through the firewall
    allowedUDPPorts = [ config.services.tailscale.port ];

    checkReversePath = "loose";
  };

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
  system.stateVersion = "22.05"; # Did you read the comment?
}

