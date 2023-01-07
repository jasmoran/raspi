{
  description = "Glaedr";

  nixConfig.extra-experimental-features = "nix-command flakes";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.05";
    impermanence.url = "github:nix-community/impermanence";
  };

  outputs = { self, nixpkgs, impermanence }: {
    nixosConfigurations.glaedr = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        impermanence.nixosModules.impermanence
        ({ config, pkgs, lib, modulesPath, ... }: {
          imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

          # Let 'nixos-version --json' know about the Git revision
          # of this flake.
          system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;

          system.stateVersion = "21.11"; # Don't change me

          environment = {
            systemPackages = with pkgs; [
              git
              tailscale
              zfs-autobackup
            ];

            # Link machine-id and zpool.cache on boot
            etc."machine-id".source = "/state/etc/machine-id";
            etc."zfs/zpool.cache".source = "/state/etc/zfs/zpool.cache";

            persistence."/state/" = {
              directories = [
                "/etc/nixos"
                "/etc/cryptkey.d"
                "/srv"
                "/var/log"
                "/var/spool"
                "/var/lib/containers"
                "/var/lib/tailscale"
                "/var/lib/iwd"
              ];
              files = [
                "/etc/aliases"
              ];
            };
          };

          nix = {
            # Improve nix store disk usage
            gc.automatic = true;

            # Prevents impurities in builds
            useSandbox = true;

            # Give root user and wheel group special Nix privileges.
            trustedUsers = [ "root" "@wheel" ];

            # Generally useful nix option defaults
            extraOptions = ''
              min-free = 536870912
              keep-outputs = true
              keep-derivations = true
              fallback = true
            '';

            # This is just a representation of the nix default
            systemFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];

            # Improve nix store disk usage
            autoOptimiseStore = true;
            optimise.automatic = true;
            allowedUsers = [ "@wheel" ];
          };

          services = {
            # Disable the OpenSSH daemon.
            openssh.enable = false;

            # Enable the tailscale service
            tailscale.enable = true;

            # Disable the X Server
            xserver.enable = false;
          };

          networking = {
            firewall = {
              # Enable the firewall
              enable = true;

              # Always allow traffic from your Tailscale network
              trustedInterfaces = [ "tailscale0" ];

              # Allow the Tailscale UDP port through the firewall
              allowedUDPPorts = [ config.services.tailscale.port ];

              checkReversePath = "loose";
            };

            useDHCP = false;
            interfaces.wlan0.useDHCP = true;

            hostId = "e5f1ab74";
            wireless.iwd.enable = true;
            networkmanager = {
              enable = true;
              wifi.backend = "iwd";
            };
          };

          fileSystems = {
            "/" = {
              device = "rpool/glaedr";
              fsType = "zfs";
              options = [ "zfsutil" "X-mount.mkdir" ];
            };
            "/boot" = {
              device = "bpool/glaedr/boot";
              fsType = "zfs";
              options = [ "zfsutil" "X-mount.mkdir" ];
            };
            "/home" = {
              device = "rpool/glaedr/home";
              fsType = "zfs";
              options = [ "zfsutil" "X-mount.mkdir" ];
            };
            "/root" = {
              device = "rpool/glaedr/root";
              fsType = "zfs";
              options = [ "zfsutil" "X-mount.mkdir" ];
            };
            "/state" = {
              device = "rpool/glaedr/state";
              fsType = "zfs";
              options = [ "zfsutil" "X-mount.mkdir" ];
              neededForBoot = true;
            };
            "/nix" = {
              device = "rpool/glaedr/nix";
              fsType = "zfs";
              options = [ "zfsutil" "X-mount.mkdir" ];
            };

            # EFI partition
            "/boot/efis/mmc-CGND3R_0x4f99f0b3-part2" = {
              device = "/dev/disk/by-id/mmc-CGND3R_0x4f99f0b3-part2";
              fsType = "vfat";
              options = [ "x-systemd.idle-timeout=1min" "x-systemd.automount" "noauto" ];
            };
          };

          boot = {
            initrd = {
              availableKernelModules = [ "ahci" "xhci_pci" "usbhid" "usb_storage" "sd_mod" "sdhci_acpi" ];
              kernelModules = [ ];
              postDeviceCommands = ''
                zpool import -Nf rpool
                zfs rollback -r rpool/glaedr@start
              '';
            };
            kernelModules = [ ];
            extraModulePackages = [ ];
            loader = {
              efi = {
                efiSysMountPoint = "/boot/efis/mmc-CGND3R_0x4f99f0b3-part2";
                canTouchEfiVariables = false;
              };
              generationsDir.copyKernels = true;
              grub = {
                enable = true;
                device = "/dev/disk/by-id/mmc-CGND3R_0x4f99f0b3";
                extraPrepareConfig = ''
                  mkdir -p /boot/efis
                  for i in  /boot/efis/*; do mount $i ; done
                '';
                version = 2;
                efiInstallAsRemovable = true;
                efiSupport = true;
                copyKernels = true;
                zfsSupport = true;
              };
            };
            supportedFilesystems = [ "zfs" ];
            zfs.devNodes = "/dev/disk/by-id";
            kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;

            # Disable NixOS containers (different from Docker containers)
            enableContainers = false;
          };

          swapDevices = [
            { device = "/dev/disk/by-id/mmc-CGND3R_0x4f99f0b3-part3"; randomEncryption.enable = true; }
          ];

          hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

          # Set your time zone.
          time.timeZone = "Pacific/Auckland";

          # Select internationalisation properties.
          i18n.defaultLocale = "en_NZ.UTF-8";

          systemd = {
            services = {
              zfs-mount.enable = false;

              # Snapshot glaedr every 5 minutes
              autobackup = {
                serviceConfig.Type = "oneshot";
                path = [ pkgs.zfs pkgs.zfs-autobackup ];
                script = "zfs-autobackup --verbose --no-thinning glaedr";
              };
            };

            timers = {
              # Snapshot glaedr every 5 minutes
              autobackup = {
                wantedBy = [ "timers.target" ];
                partOf = [ "autobackup.service" ];
                timerConfig = {
                  OnCalendar = "*:0/5:0";
                  Unit = "autobackup.service";
                };
              };
            };
          };

          sound.enable = false;

          users = {
            mutableUsers = false;
            users = {
              media = {
                description = "Media";
                isNormalUser = true;
                extraGroups = [ "wheel" ];
                hashedPassword = "$6$5a/m8fUb0PPEfNCj$YnCUJE7rdm/AxK2HB/JVFWsSYRDzjz46E8TjegLxRn9zy6Yrk0AY1udvkY4iavQO4kuXkTIezSXVVhm77lusP1";
                openssh.authorizedKeys.keys = [];
              };
              jellyfin = {
                isSystemUser = true;
                createHome = true;
                home = "/home/jellyfin";
                group = "jellyfin";
              };
            };
            groups = {
              jellyfin = {};
            };
          };

          # Enable podman
          virtualisation = {
            podman.enable = true;
            oci-containers = {
              backend = "podman";
              containers = {
                jellyfin = {
                  autoStart = true;
                  image = "docker.io/jellyfin/jellyfin:latest";
                  ports = ["8096:8096/tcp"];
                  volumes = [
                    "jellyfin-cache:/cache:Z"
                    "jellyfin-config:/config:Z"
                    "/data/TV:/TV:ro"
                    "/data/Movies:/Movies:ro"
                    "/data/HomeMedia:/HomeMedia:ro"
                  ];
                };
              };
            };
          };
        })
      ];
    };
  };
}
