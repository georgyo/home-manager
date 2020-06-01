{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.lieer;

  syncAccounts = filter (a: a.lieer.enable && a.lieer.sync.enable)
    (attrValues config.accounts.email.accounts);

  escapeUnitName = name:
    let
      good = upperChars ++ lowerChars ++ stringToCharacters "0123456789-_";
      subst = c: if any (x: x == c) good then c else "-";
    in stringAsChars subst name;

  serviceUnit = syncAccounts: {
    name = escapeUnitName "lieer-sync";
    value = {
      Unit = {
        Description = "lieer Gmail synchronization";
        ConditionPathExists = [ (map (account: "${account.maildir.absPath}/.gmailieer.json") syncAccounts)];
      };

      Service = {
        Type = "oneshot";
        ExecStart = [ (map (account: "${pkgs.bash}/bin/bash -c \"cd ${account.maildir.absPath} && ${pkgs.gmailieer}/bin/gmi sync\"") syncAccounts)];
      };
    };
  };

  timerUnit = syncAccounts: {
    name = escapeUnitName "lieer-sync";
    value = {
      Unit = {
        Description = "lieer Gmail synchronization";
      };

      Timer = {
        OnCalendar = "*:0/5";
        RandomizedDelaySec = 30;
      };

      Install = { WantedBy = [ "timers.target" ]; };
    };
  };

in {
  meta.maintainers = [ maintainers.tadfisher ];

  options = {
    services.lieer.enable =
      mkEnableOption "lieer Gmail synchronization service";
  };

  config = mkIf cfg.enable {
    programs.lieer.enable = true;
    systemd.user.services = listToAttrs [(serviceUnit syncAccounts)];
    systemd.user.timers = listToAttrs [(timerUnit syncAccounts)];
  };
}
