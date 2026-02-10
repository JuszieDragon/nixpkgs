{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    types
    mkIf
    mkOption
    mkEnableOption
    mkPackageOption
    optionalString
    ;

  cfg = config.services.yarr;
in
{
  meta.maintainers = with lib.maintainers; [ christoph-heiss ];

  options.services.yarr = {
    enable = mkEnableOption "Yet another rss reader";

    package = mkPackageOption pkgs "yarr" { };

    user = mkOption {
      type = types.str;
      default = "yarr";
      description = "User account under which yarr runs.";
    };

    group = mkOption {
      type = types.str;
      default = "yarr";
      description = "Group under which yarr runs.";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Environment file for specifying additional settings such as secrets.

        See `yarr -help` for all available options.
      '';
    };

    address = mkOption {
      type = types.str;
      default = "localhost";
      description = "Address to run server on.";
    };

    port = mkOption {
      type = types.port;
      default = 7070;
      description = "Port to run server on.";
    };

    baseUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Base path of the service url.";
    };

    authFilePath = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to a file containing username:password. `null` means no authentication required to use the service.";
    };

    dbPath = mkOption {
      type = types.nullOr types.path;
      default = "/var/lib/yarr/storage.db";
      description = "The directory to store service state.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.yarr = {
      description = "Yet another rss reader";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment.XDG_CONFIG_HOME = "/var/lib/yarr/.config";

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";

        EnvironmentFile = cfg.environmentFile;

        LoadCredential = mkIf (cfg.authFilePath != null) "authfile:${cfg.authFilePath}";

        DevicePolicy = "closed";
        LockPersonality = "yes";
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateMounts = true;
        PrivateTmp = true;
        ProcSubset = "pid";
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProtectSystem = "full";
        RemoveIPC = true;
        RestrictAddressFamilies = "AF_INET AF_INET6";
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        UMask = "0077";

        ExecStart = ''
          ${lib.getExe cfg.package} \
            -db ${cfg.dbPath} \
            -addr "${cfg.address}:${toString cfg.port}" \
            ${optionalString (cfg.baseUrl != null) "-base ${cfg.baseUrl}"} \
            ${optionalString (cfg.authFilePath != null) "-auth-file /run/credentials/yarr.service/authfile"}
        '';
      };
    };

    users = {
      users = mkIf (cfg.user == "yarr") {
        yarr = {
          inherit (cfg) group;
          isSystemUser = true;
        };
      };
      groups = mkIf (cfg.group == "yarr") { yarr = { }; };
    };
  };
}
