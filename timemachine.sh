#!/bin/sh
# stop on error, generally good practice
set -e;

PKGS="busybox shadow-usermod blkid netatalk avahi-daemon";
SCRIPT="$0";
SCRIPTNAME=$(basename "$SCRIPT");
ARGS=$*;
USER="$1";
PASS="$2";
CONT="$3";
CONFIGS="/jffs/configs";
SCRIPTS="/jffs/scripts";

backup() {
  line "Backing up $1.. ";
  if [ ! -f "$1" ]; then
    echo "File not found";
  else
    BAK="$1.backup";
    echo -n "- $BAK.. ";
    cp "$1" "$BAK";
    chmod -x "$BAK";
    echo "done.";

    TMP="/tmp/$(basename "$1").backup";
    echo -n "- $TMP.. ";
    cp "$1" "$TMP";
    chmod -x "$TMP";
    echo "done"
  fi;
}

line() {
  MSG="$*";
  echo "";
  echo "---";
  echo "";
  if [ "$MSG" != "" ]; then
    echo "$MSG";
    echo "";
  fi;
}

banner() {
  line "Time Machine installation script";
  echo "Only tested with asuswrt-merlin on Asus RT-AC66U.";
}

usage() {
  line    "Usage: $SCRIPTNAME [user [password]]"
  echo -n "To make it easy, use the exact full name you use as your user";
  echo    " in Mac OS X. Also use the same password for automatic login.";
}

pause() {
  echo "";
  echo "Press [CTRL-C] to cancel, or [ENTER] to continue.";
  read -p "" ANS;
}

go() {
  echo -n "$* (Y/n) ";
  if [ "$CONT" != "" ]; then
    echo "y";
    return 0;
  fi;

  read -p "" A;
  if [ "$A" = "" ] || [ "$A" = "Y" ] || [ "$A" = "y" ]; then
    return 0;
  fi;
  return 127;
}

nogo() {
  echo -n "$* (y/N) ";
  if [ "$CONT" != "" ]; then
    echo "n";
    return 0;
  fi;

  read -p "" A;
  if [ "$A" = "" ] || [ "$A" = "N" ] || [ "$A" = "n" ]; then
    return 0;
  fi;
  return 127;
}

checkJFFS() {
  mount | grep jffs | wc -l;
}

fixJFFS() {
  echo "- Trying to enable missing JFFS partition.";
  if [ $(checkJFFS) = "1" ]; then
    echo "- !! Found it.. why is this run? !!";
    return 127;
  fi

  ENABLED=$(nvram get jffs2_on);
  if [ "$ENABLED" = "1" ]; then
    echo "- !! JFFS already enabled, but not found.. I'll try a JFFS format. !!";
    echo "- !! If you've already run this script, try rebooting. !!";
  fi;

  nvram set jffs2_on=1;
  nvram set jffs2_format=1;
  nvram commit;

  return 0;
}

checkEntware() {
  OPKG_VERSION="$(/opt/bin/opkg -v 2>/dev/null)";
  echo "$?";
}

fixEntware() {
  entware-setup.sh || echo "- Entware setup failed";
  return 0;
}

prerequisites() {
  line "Checking prerequisites";
  STOP=false;
  REBOOT=false;
  JFFS_COUNT=$(checkJFFS);
  if [ "$JFFS_COUNT" = "0" ]; then
    echo "JFFS is required, but not enabled:";
    echo "- https://github.com/RMerl/asuswrt-merlin/wiki/JFFS";

    STOP=true;
    ( go "Try to autofix?" &&
      ( fixJFFS &&
        echo "- Fixed JFFS partition, reboot required" &&
        return 0 )
    ) && go "Need to reboot, do it now?" &&
            echo "Re-run this script on reboot:" &&
            echo "$ $SCRIPT $ARGS" &&
            reboot &&
            exit 0;
  else
    echo "- JFFS partition found";
  fi;

  OPKG_CHECK=$(checkEntware);
  if [ "$OPKG_CHECK" != "0" ]; then
    echo "Entware is required, but not found:";
    echo "- https://github.com/RMerl/asuswrt-merlin/wiki/Entware";

    STOP=true;
    ( go "Try to autofix?" &&
      ( fixEntware &&
        echo "- Fixed Entware" &&
        return 0 )
    ) && STOP=false;
  else
    echo "- Entware found";
  fi;

  if ! $STOP; then
    if [ "$USER" = "" ]; then
      usage;
      echo "";
      echo -n "Username: ";
      read -p "" USER;
    fi;

    if [ "$USER" = "" ]; then
      echo "Supply a username.";
      STOP=true
    fi;
  fi;

  if $STOP; then
    echo "Prerequisites not met, fix the issues and rerun script.";
    return 127;
  fi;
}

steps() {
  line "Steps:";
  echo "- Install packages: $PKGS"
  echo "- Add user $USER";
  echo "- Make user persistent in /jffs/configs";
  echo "- Set netatalk config /opt/etc/netatalk/afpd.conf";
  echo "- Create post-mount script for netatalk";
  echo "- Set avahi-daemon config /opt/etc/avahi/avahi-daemon.conf";
}

installPackages() {
  line "Install packages: $*";
  /opt/bin/opkg install $* || return 127;
}

getPasswd() {
  cat /etc/passwd | grep "$1:";
  return 0;
}

getShadow() {
  cat /etc/shadow | grep "$1:";
  return 0;
}

getGroup() {
  cat /etc/group  | grep "$1:";
  return 0;
}

addUser() {
  MSG="Add user \"$1\""
  if [ $# -gt 1 ]; then
    if [ "$2" = "" ]; then
      MSG="$MSG with user-interactive password";
    else
      MSG="$MSG with password \"*******\"";
    fi;
  else
    MSG="$MSG without password";
  fi;

  line "$MSG";
  PASSWD=$(getPasswd "$1");

  if [ "$PASSWD" != "" ]; then
    echo "User already exists.";
    echo "/etc/passwd:";
    echo "# $PASSWD";

    SHADOW=$(getShadow "$1");
    if [ $# -gt 1 ] && [ "$SHADOW" = "" ]; then
      setPasswd "$1" "$2";
    fi;
    return 0;
  fi;

  echo -n "User doesn't exist, adding ";
  /opt/bin/adduser -D "$1";
  if [ $# -gt 1 ] && [ "$2" = "" ]; then
    setPasswd "$1" "2";
  fi;
}

setPasswd() {
  line "Set password for \"$1\" to \"$2\"";
  SHADOW=$(getShadow "$1");

  if [ "$SHADOW" != "" ]; then
    echo "/etc/shadow:";
    echo "# $SHADOW";
    echo "";
  fi

  if [ "$2" != "" ]; then
    /opt/sbin/usermod -p "$2" "$1";
    echo "Password set from script.";
  else
    if [ "$SHADOW" = "" ]; then
      /bin/passwd "$1" || (echo "Retry.." && setPasswd "$1" "$2");
      echo "Password set user-interactive from passwd.";
    else
      echo "Password already set. To reset password run:";
      echo "$ passwd \"$1\"";
    fi;
  fi;
}

addGroup() {
  GROUP=$(getGroup "$1");
  if [ "$GROUP" = "" ]; then
    /opt/bin/addgroup "$1";
  fi;
  echo    "/etc/group:";
  echo -n "# $GROUP";
  echo    "$(getGroup "$1")";
}

delGroup() {
  line "Deleting group $1.. ";
  DELETED=false;
  /opt/bin/delgroup "$1" && DELETED=true;
  if $DELETED; then
    echo "- Group deleted";
  else
    echo "- Group not found or in use";
  fi;
}

persistUser() {
  line "Persist user $1";

  P="$CONFIGS/passwd.add";
  sed -i "/$1:/d" "$P";
  getPasswd "$1" >>"$P";
  line "# $P";
  cat "$P";

  S="$CONFIGS/shadow.add";
  sed -i "/$1:/d" "$S";
  getShadow "$1" >>"$S";
  line "# $S";
  cat "$S";
}

persistGroup() {
  G="$CONFIGS/group.add";
  touch "$G";

  line "Persist group $1";
  sed -i "/$1:/d" "$G";
  getGroup "$1" >>"$G";
  line "# $G";
  cat "$G"
}

installAFPDConf() {
  S="/opt/etc/netatalk/afpd.conf";
  line "Install afpd.conf to $S";
  backup "$S";
  echo -n "- -transall -nouservol -setuplog \"default log_info" >"$S";
  echo -n " /opt/var/log/afpd.log\" -defaultvol" >>"$S";
  echo -n " /opt/etc/netatalk/AppleVolumes.default -systemvol" >>"$S";
  echo -n " /opt/etc/netatalk/AppleVolumes.system -noddp -uamlist" >>"$S";
  echo    " uams_dhx2.so" >>"$S";

  echo    "$S:";
  echo -n "# ";
  cat     "$S";
}

installAFPDMountScript() {
  P="$SCRIPTS/post-mount";
  A="$SCRIPTS/afpd-mount";
  backup "$P";
  backup "$A";

  if [ ! -f "$P" ]; then
    echo "#!/bin/sh" >"$P";
  fi;
  sed -i '/afpd-mount/d' "$P";
  echo "$A" >>"$P";
  line "$A";
  tee "$A" <<EOS
#!/bin/sh
USER="$1";
TARGET="/opt/etc/netatalk/AppleVolumes.default";

cp "\$TARGET" "\$TARGET.bak";
echo "-" >"\$TARGET";

mount | grep "/dev/sd" | while read L; do
  DEV=\$(echo "\$L" | awk '{print \$1}');
  POINT=\$(echo "\$L" | awk '{print \$3}');
  NAME="\$(/opt/sbin/blkid -o value -s LABEL \$DEV)";
  if [ "\$NAME" = "" ]; then
    NAME="\${DEV:5}";
  fi;
  echo "Create share: \$DEV -> \$POINT (\$NAME)";
  SHARE="\$POINT \"\$NAME\" cnidscheme:dbd options:usedots,upriv,tm"
  SHARE="\$SHARE allow:\"\$USER\"";
  echo "# \$SHARE";
  echo "\$SHARE" >>"\$TARGET";
done;

/opt/etc/init.d/S27afpd reconfigure;
EOS

  chmod +x "$A";
}

installAvahiConf() {
  line "Installing Avahi configuration";
  BASE="/opt/etc/avahi";
  echo "- In $BASE";

  CONF="$BASE/avahi-daemon.conf";
  backup "$CONF";
  line "# $CONF:";
  tee "$CONF" <<EOS
[server]
host-name=$(nvram get computer_name)
domain-name=$(nvram get lan_domain)
use-ipv4=yes
use-ipv6=no
check-response-ttl=no
use-iff-running=no
enable-dbus=no
deny-interfaces=eth0

[publish]
publish-addresses=yes
publish-hinfo=yes
publish-workstation=yes
publish-domain=yes
publish-dns-servers=$(nvram get lan_ipaddr)
publish-resolv-conf-dns-servers=yes

[reflector]
enable-reflector=yes
reflect-ipv=no

[rlimits]
rlimit-core=0
rlimit-data=4194304
rlimit-fsize=0
rlimit-nofile=30
rlimit-stack=4194304
rlimit-nproc=3
EOS

  SERVICES="$BASE/services";
  AFPD="$SERVICES/afpd.service";
  backup "$AFPD";
  line "# $AFPD";
  tee "$AFPD" <<EOS
<?xml version="1.0" standalone='no'?><!--*-nxml-*-->
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">%h</name>
  <service>
    <type>_afpovertcp._tcp</type>
    <port>548</port>
  </service>
  <service>
    <type>_device-info._tcp</type>
    <port>0</port>
    <txt-record>model=AirPort</txt-record>
  </service>
</service-group>
EOS

  SSH="$SERVICES/ssh.service";
  backup "$SSH";
  line "# $SSH";
  tee "$SSH" <<EOS
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">Secure Shell on %h</name>
  <service>
    <type>_ssh._tcp</type>
    <port>22</port>
  </service>
</service-group>
EOS

  HTTP="$SERVICES/http.service";
  backup "$HTTP";
  line "# $HTTP";
  tee "$HTTP" <<EOS
<?xml version="1.0" standalone='no'?><!--*-nxml-*-->
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">Web Server on %h</name>
  <service>
    <type>_http._tcp</type>
    <port>80</port>
    <txt-record>path=/</txt-record>
  </service>
</service-group>
EOS

  SAMBA="$SERVICES/samba.service";
  backup "$SAMBA";
  line "# $SAMBA";
  tee "$SAMBA" <<EOS
<?xml version="{1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">Samba Shares on %h</name>
  <service>
    <type>_smb._tcp</type>
    <port>139</port>
  </service>
</service-group>
EOS

  /opt/etc/init.d/S42avahi-daemon restart
}

## ITINERARY
banner;
prerequisites;
steps;
installPackages $PKGS;
addUser "$USER" "$PASS";
setPasswd "$USER" "$PASS";
persistUser "$USER";
persistGroup "$USER";
installAFPDConf;
installAFPDMountScript "$USER";

delGroup "avahi";
addUser "avahi";
persistGroup "avahi";
persistUser "avahi";
installAvahiConf;

( go "It's probably a good idea to reboot now.. Shall we do that?" &&
  reboot
);
