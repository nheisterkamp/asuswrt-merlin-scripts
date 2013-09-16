#!/bin/sh
banner() {
  echo ""
  echo ""
  echo -e -n "\033[1m"
  echo "     ##########################################################"
  echo "     ####                                                     #"
  echo "     ####  Time Machine -and soon more- installation magic    #"
  echo "     ####  ------------------------------------------------   #"
  echo "     ####  Only tested with asuswrt-merlin on Asus RT-AC66U   #"
  echo "     ####  and external HD with just one partition formatted  #"
  echo "     ####  as ext3, but is prepared for multiple HDs and      #"
  echo "     ####  USB hotswapping.                                   #"
  echo "     ####                                                     #"
  echo "     ##########################################################"
  echo ""
  echo "Example: "
  echo "VERBOSITY=3 CONTINUE=\"yes\" \\"
  echo "AFPD_USER=\"Niels Heisterkamp\" AFPD_PASS=\"secret\" \\"
  echo "TIME_SHARE=true TIME_NAME=\"TimeMachine\" TIME_SIZE=200000 \\"
  echo "sh timemachine.sh"
  echo -e -n "\033[0m"
}

usage() {
  line $SIL "Usage: $FILENAME"
  log $SIL "Make sure you have:"
  log $SIL "* asuswrt-merlin installed"
  log $SIL "* attached a USB disk with at least one ext3 partition"
  log $SIL "* set the following things in the web interface"
  log $SIL "  - your routers hostname"
  log $SIL "  - an admin user for the web interface"
  log $SIL "  - enabled JFFS (optional, but requires a reboot)"
  log $SIL ""
  log $SIL "Global variables (these can be set by setting them before launching):"
  log $SIL "  FILENAME   = $FILENAME"
  log $SIL "  VERBOSITY  = $VERBOSITY"
  log $SIL "  CONTINUE   = $CONTINUE"
  log $SIL "  INSTALL    = $INSTALL"
  plainLine

  if ! $SOURCED; then
    if ! go "Ready?"; then
      exit 127
    fi
  fi
}

settings() {
  # stop when error occurs
  set -e
  ## VARIABLES {{
  # script filename -- needed to determine if this script is called or sourced
  FILENAME=${FILENAME:-"timemachine.sh"}
  # scale 0,1,2,3,4 = banners,error,warning,info,verbose,data
  VERBOSITY=${VERBOSITY:-4}
  # always answer yes on questions
  CONTINUE=${CONTINUE:-"no"}
  # currently available installers
  INSTALL=${INSTALL:-"netatalk avahi transmission"}
  # path
  PATH="/opt/usr/sbin:/opt/sbin:/opt/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin"
  ## }}
}

main() {
  init

  if ! $SOURCED; then
    line $SIL "Which packages would you like:"

    for NAME in $INSTALL; do
      ${NAME}Check
      if go "Install $NAME?"; then
        ${NAME}Install
      fi
    done

    line $SIL "We're done, reboot!"
  else
    line $SIL "The functions are at your disposal"
  fi
}

entwareBase() {
  mount | grep $(df -P /opt | tail -1 | cut -d' ' -f 1) | awk '{print $3}';
}

netatalkCheck() {
  log $SIL "Package: netatalk:"
  AFPD_USER=${AFPD_USER:=$CURRENT_USER}
  AFPD_PASS=${AFPD_PASS:=$AFPD_USER}
  AFPD_GUEST=${AFPD_GUEST:=false}
  if [ "$AFPD_GUEST" = "1" ]; then
    AFPD_GUEST=true
  else
    AFPD_GUEST=false
  fi;

  log $SIL "  AFPD_USER  = $AFPD_USER"
  log $SIL "  AFPD_PASS  = $AFPD_PASS"
  log $SIL "  AFPD_GUEST = $AFPD_GUEST"

  if [ "$TIME_SHARE" = "true" ]; then
    export TIME_NAME=${TIME_NAME:=TimeMachine}
    export TIME_LOC=${TIME_LOC:="$(entwareBase)/$TIME_NAME"}
    export TIME_SIZE=${TIME_SIZE:=200000}

    log $SIL "* TIME_SHARE = $TIME_SHARE"
    log $SIL "* TIME_NAME  = $TIME_NAME"
    log $SIL "* TIME_LOC   = $TIME_LOC"
    log $SIL "* TIME_SIZE  = $TIME_SIZE"
  fi
}

netatalkInstall() {
  line $WAR "Installing netatalk"
  log $INF "Steps:"
  log $INF "* Install netatalk"
  log $INF "* Set netatalk config /opt/etc/netatalk/afpd.conf"
  log $INF "* Create post-mount script for netatalk"

  if [ "$AFPD_USER" = "" ]; then
    CURRENT_USER="$USER"

    echo -n "- Username [$CURRENT_USER]: "
    if [ "$CONTINUE" = "yes" ]; then
      echo "$CURRENT_USER"
    else
      read -p "" AFPD_USER
    fi

    if [ "$AFPD_USER" = "" ]; then
      AFPD_USER="$CURRENT_USER"
    fi
  fi

  installPackages netatalk
  line $WAR ""

  if [ "$AFPD_USER" != "" ]; then
    addUser "$AFPD_USER" "$AFPD_PASS"
  fi

  if [ "$TIME_SHARE" = "true" ]; then
    export -p | grep "TIME_" >"$CONFIGS/timemachine.vars"
    chmod +x "$CONFIGS/timemachine.vars"
    mkdir -p "$TIME_LOC"
    chown "$AFPD_USER:$AFPD_USER" -R "$TIME_LOC/"*
  fi

  addUser "nobody"
  installAFPDConf
  installAFPDMountScript "$AFPD_USER"

  /jffs/scripts/afpd-mount && /opt/etc/init.d/S27afpd reconfigure
}

avahiCheck() {
  :
}

avahiInstall() {
  line $INF "Installing avahi"
  log $INF "Steps:"
  log $INF "* Set avahi-daemon config /opt/etc/avahi/avahi-daemon.conf"

  installPackages avahi-daemon

  addGroup "nogroup"
  addGroup "avahi"
  addUser  "avahi"

  avahiInstallConf
  line $INF ""
}

opensshCheck() {
  :
}

opensshInstall() {
  installPackages "openssh-server"
  addUser "sshd"
}

transmissionCheck() {
  TRANS_DIRE=${TRANS_DIRE:="$(entwareBase)/Downloads"}
  TRANS_CMPL=${TRANS_COMP:="$TRANS_DIRE/Complete"}
  TRANS_INCO=${TRANS_INCO:="$TRANS_DIRE/Incomplete"}
  TRANS_WATC=${TRANS_WATC:="$TRANS_DIRE/Watchdir"}
  TRANS_CONF=${TRANS_CONF:="$TRANS_DIRE/Config"}
  TRANS_USER=${TRANS_USER:="$USER"}
  TRANS_USER=${TRANS_USER:="$AFPD_USER"}
  TRANS_PASS=${TRANS_PASS:="$AFPD_PASS"}

  log $SIL "Transmission variables:"
  log $SIL "  TRANS_DIRE = $TRANS_DIRE"
  log $SIL "  TRANS_CMPL = $TRANS_CMPL"
  log $SIL "  TRANS_INCO = $TRANS_INCO"
  log $SIL "  TRANS_WATC = $TRANS_WATC"
  log $SIL "  TRANS_USER = $TRANS_USER"
  log $SIL "  TRANS_PASS = $TRANS_PASS"
}

# transmissionSetting() {
#   FILE="$1"; KEY="$2"; VALUE="$3";
#   sed -i -r "s#(\"$KEY\": )(\"?)([^\"]*)(\"?)(,?)#\1\2$VALUE\4\5#w" "$FILE"
# }

transmissionInstall() {
  line $INF "Installing Transmission"
  installPackages transmission-daemon transmission-web
  /opt/etc/init.d/S88transmission stop || echo " - He's dead, Jim."

  # FILE="/opt/etc/transmission/settings.json"
  backup "$FILE"
  mkdir -p "$TRANS_DIRE" "$TRANS_INCO" "$TRANS_CMPL" "$TRANS_WATC" "$TRANS_CONF"

  # transmissionSetting "$FILE" "download-dir"           "$TRANS_CMPL"
  # transmissionSetting "$FILE" "incomplete-dir"         "$TRANS_INCO"
  # transmissionSetting "$FILE" "incomplete-dir-enabled" "true"
  # transmissionSetting "$FILE" "rpc-bind-address"       "$(nvram get lan_ipaddr)"
  # transmissionSetting "$FILE" "rpc-password"           "$TRANS_PASS"
  # transmissionSetting "$FILE" "rpc-username"           "$TRANS_USER"
  # transmissionSetting "$FILE" "watch-dir"              "$TRANS_WATC"
  # transmissionSetting "$FILE" "watch-dir-enabled"      "true"

  # cat "$FILE"
  transmission-daemon --config-dir "/opt/etc/transmission" \
                       --watch-dir "$TRANS_WATC" \
                  --incomplete-dir "$TRANS_INCO" \
                            --auth \
                        --username "$TRANS_USER" \
                        --password "$TRANS_PASS" \
                    --download-dir "$TRANS_CMPL" \
                         --portmap \
                         --allowed "*" \
                   --dump-settings 2>"$TRANS_CONF/settings.json"
                # --rpc-bind-address "$(nvram get lan_ipaddr)" \

  sed -i "s#^(ARGS=\")([^\"]*)(\")#\1-g \"$TRANS_CONF/settings.json\"\3#" \
         "/opt/etc/init.d/S88transmission"

  /opt/etc/init.d/S88transmission start
  line $INF ""
}

################################################################################
## HELPER FUNCTIONS DOWN HERE
init() {
  settings

  ## CONSTANTish {{
  CONFIGS="/jffs/configs"
  SCRIPTS="/jffs/scripts"
  BACKUPDIR="/opt/backup"
  # }}

  #@ CONSTANTS FOR LOGGING {{
  if [ "$SIL" != "0" ]; then
    SIL=0; readonly SIL
    ERR=1; readonly ERR
    WAR=2; readonly WAR
    INF=3; readonly INF
    VER=4; readonly VER
    DAT=5; readonly DAT
  fi
  ## }}

  ## check if we are being sourced
  SOURCED=false
  if [ $(basename -- "$0") != "$FILENAME" ]; then
    SOURCED=true
  fi

  banner
  usage
  autorun
  prerequisites
  installPackages busybox shadow-passwd shadow-usermod blkid nano
}

autorun() {
  if $SOURCED; then
    return 0
  fi

  if [ "$CONTINUE" != "yes" ]; then
    line $SIL "Automatically run the entire script? Press A and then [ENTER]"
    MSG=$(cat - <<EOM
If you want, you can take this opportunity to answer with A and
let the script decide what is seems reasonable -- this can cause
some unfortunate side-effects and should probably only be run on
a freshly installed system.
EOM
    );
    go "$MSG"
  fi
}

backup() {
  MSG="- Backing up $1"

  mkdir -p "$BACKUPDIR"
  if [ ! -f "$1" ]; then
    MSG="$MSG.. file not found"
  else
    BAK="$BACKUPDIR/$1.backup"
    mkdir -p $(dirname $BAK)
    MSG="$MSG to $BAK. "
    cp "$1" "$BAK"
    chmod -x "$BAK"
    MSG="$MSG done."
  fi
  log $DAT "$MSG"
}

logLevel() {
  LVL=$1
  if [ "$LVL" = "" ]; then
    LVL=4
  fi
  echo $LVL
  return 0
}

logPrefix() {
  case $(logLevel $1) in
      0 ) echo "\033[3m";     break;;
      1 ) echo "\033[1m\033[4m(E) "; break;;
      2 ) echo "\033[1m\033[4m(W) "; break;;
      3 ) echo "\033[1m(I) "; break;;
      4 ) echo "(V) "; break;;
      5 ) echo "";     break;;
      * ) echo "(B) "; return 1;;
  esac
  return 0
}

logShow() {
  if [ "$VERBOSITY" = "" ]; then
    VERBOSITY=4
  fi
  if [ $(logLevel $1) -le $VERBOSITY ]; then
    return 0
  fi
  return 1
}

log() {
  if logShow $1; then
    PREFIX="$(logPrefix $1)";
    echo -e "${PREFIX}${2}"
    if [ "${PREFIX}" != "" ]; then
      echo -n -e "\033[0m"
    fi
  fi

  return 0
}

plainLine() {
  echo "-----------------------------------------------------------------------"
}

line() {
  if logShow $1; then
    if [ "$2" = "" ]; then
      if [ $VERBOSITY -gt 2 ]; then
        plainLine
      fi
    else
      if [ $VERBOSITY -gt 2 ]; then
        echo ""
      fi
      plainLine
      echo -e "\033[1m### $2\033[0m"
    fi
  fi
}

go() {
  QUESTION="- $1 (Y/n/a) "

  if [ "$CONTINUE" = "yes" ]; then
    echo "${QUESTION}yes"
    return 0
  fi

  if [ "$2" != "" ]; then
    TIMEOUT=$2
    QUESTION="${QUESTION}answering [y] in $TIMEOUT seconds: "
  fi
  while true; do
    echo -n "$QUESTION"

    if [ "$TIMEOUT" != "" ]; then
      read -t $TIMEOUT -p "" T || echo ""
    else
      read -p "" T
    fi

    A=${T:0:1}
    case "$A" in
      Y | y | "" ) return 0;;
      N | n      ) return 1;;
      A | a      ) echo "- Saying yes to everything!"
                   CONTINUE="yes"
                   return 0;;
      *          ) echo "- Please answer [y]es or [n]o..";;
    esac
  done
}

reboot() {
  line $SIL "Going down for reboot!"
  sleep 2
  /sbin/reboot
  line $SIL ""
}

checkJFFS() {
  W=$(mount | grep jffs | wc -l)
  if [ "$W" = "0" ]; then
    return 1
  fi
  return 0
}

nvramJFFSEnabled() {
  if [ $(nvram get jffs2_on) = "1" ]; then
    return 0
  fi
  return 1
}

fixJFFS() {
  log $WAR "Trying to enable missing JFFS partition."
  if checkJFFS; then
    line $ERR "Found it.. why is this run?"
    line $WAR ""
    return 1
  fi

  if nvramJFFSEnabled; then
    log $VER "JFFS already enabled, but not found!"
    if go "Have you already rebooted?"; then
      if go "Do you want to format the JFFS partition?"; then
        nvram set jffs2_format=1
        nvram commit
      fi
    fi
  else
    nvram set jffs2_on=1
    nvram set jffs2_format=1
    nvram commit
  fi

  line $WAR ""
  return 0
}

checkEntware() {
  /opt/bin/opkg -v 2>/dev/null >/dev/null || return 1
  return 0
}

fixEntware() {
  if [ -L rm /tmp/opt ]; then
    rm /tmp/opt
  fi
  /usr/sbin/entware-setup.sh || return 1
  return 0
}

prerequisites() {
  line $INF "Checking prerequisites"
  STOP=false
  if ! checkJFFS; then
    line $WAR "JFFS is required, but not enabled:"
    log $WAR "More info: https://github.com/RMerl/asuswrt-merlin/wiki/JFFS"

    STOP=true
    if go "Try to autofix?"; then
      if fixJFFS; then
        log $WAR "Fixed JFFS partition, reboot required"

        if go "Need to reboot, do it now?"; then
          log $ERR "Reboot is required to continue!"
          log $ERR "Re-run this script after reboot"
          reboot
          exit 0
        fi
      else
        log $ERR "JFFS autofix failed ;("
      fi
    fi
  else
    log $INF "JFFS partition found"
  fi

  if ! checkEntware; then
    log $WAR "Entware is required, but not found:"
    log $WAR "- https://github.com/RMerl/asuswrt-merlin/wiki/Entware"

    if go "Try to autofix?"; then
      if fixEntware; then
        log $WAR "Entware probably installed :)"
        if checkEntware; then
          log $WAR "It worked :)"
        else
          STOP=true;
          log $ERR "Something went wrong :("
          log $ERR "This is probably something leftover from a previous version"
          if [ -L "/tmp/opt" ]; then
            rm "/tmp/opt"
            log $ERR "Found it :D Let's try again"
            prerequisites
            return 0
          else
            log $ERR; "Didn't find anything, I'm lost.."
          fi
        fi
      else
        STOP=true
        if go "Autofix failed, are you sure you have an ext3 partition?"; then
          if go "Perhaps sir would enjoy a reboot?"; then
            reboot
            line $INF ""
            return 1
          fi
        fi
      fi
    fi
  else
    log $INF "Entware found"
  fi

  for FILE in "passwd" "group" "shadow"; do
    if [ ! -f "/opt/etc/$FILE" ]; then
      log $VER "Symlinking /etc/$FILE -> /opt/etc/$FILE"
      ln -s "/etc/$FILE" "/opt/etc/$FILE"
    fi
  done

  if $STOP; then
    echo "Prerequisites not met, fix the issues and rerun script."
    line $INF ""
    return 1
  fi
  line $INF ""
}

installPackages() {
  log $INF "Install packages: $*"
  if logShow 3; then
    /opt/bin/opkg install $* || return 1
  else
    /opt/bin/opkg install $* >/dev/null || return 1
  fi
  line $INF ""
  return 0
}

getPasswd() {
  grep "$1:" /etc/passwd
  return 0
}

getShadow() {
  grep "$1:" /etc/shadow
  return 0
}

getGroup() {
  grep "$1:" /etc/group
  return 0
}

addUser() {
  log $INF "Add user \"$1\""

  PASSWD=$(getPasswd "$1" | head -1)
  if [ "$PASSWD" != "" ]; then
    log $INF "Setting password"
    if [ $# -gt 1 ]; then
      setPasswd "$1" "$2"
    fi
    return 0
  fi

  log $INF "User doesn't exist, adding.."
  /opt/bin/adduser -D "$1" || log $WAR "User already exists"

  if [ $# -gt 1 ] && [ "$2" = "" ]; then
    setPasswd "$1" "2"
  fi

  persistUser "$AFPD_USER"
}

setPasswd() {
  line $INF "Set password for \"$1\" to \"******\""

  if [ $# -eq 1 ]; then
    log $INF "Not going to set a password"
  elif [ "$2" != "" ]; then
    SALT=$(S=</dev/urandom tr -dc A-Za-z0-9 | head -c 16)
    log $INF "Salt: $SALT"
    /opt/sbin/usermod -p $(mkpasswd -m sha-512 "$2" "$SALT") "$1"
    log $INF "Password set from script."
  fi

  line $INF ""
}

addGroup() {
  GROUP=$(getGroup "$1")
  if [ "$GROUP" = "" ]; then
    /opt/bin/addgroup "$1"
  fi
  persistGroup "$1"
}

delGroup() {
  line $VER "Deleting group $1.. "
  DELETED=true
  /opt/bin/delgroup "$1" 2>&1 >/dev/null || DELETED=false
  editConfig "group.add" "$1" ""
  if $DELETED; then
    log $VER "group deleted"
  else
    log $VER "deletion failed"
  fi
  line $VER ""
}

editConfig() { # $FILE $FIND $NEW
  FILE="$1"
  FIND="$2"
  NEW="$3"

  backup "$FILE"
  touch "$FILE"

  MATCHES=$(sed "/$1/!d" "$FILE")
  log $VER "editConfig FILE=$FILE FIND=$FIND NEW=$NEW"
  log $VER $MATCHES

  sed -i "/$1/d" "$FILE"

  for MATCH in $MATCHES; do
    log $DAT "$FILE removed line: $MATCH"
  done

  if [ "$NEW" != "" ]; then
    echo "$NEW" >>"$FILE"
    log $DAT "$FILE added line: $NEW"
  fi
}

persistSave() { # $FILE $KEY $VALUE
  log $VER "Storing in $1 for $2 : $3"
  BASE="$CONFIGS/$1"
  DIR="$BASE.d"
  mkdir -p "$DIR"
  echo "$3" >"$DIR/$2"
  cat "$DIR/"* >"$BASE"
}

persistUser() {
  line $VER "Persist user $1"
  persistSave "passwd.add" "$1" "$(getPasswd "$1")"
  persistSave "shadow.add" "$1" "$(getShadow "$1")"
  line $VER ""

  persistGroup "$1"
}

persistGroup() {
  line $VER "Persist group $1"
  persistSave "group.add" "$1" "$(getGroup "$1")"
  line $VER ""
}

installAFPDConf() {
  S="/opt/etc/netatalk/afpd.conf"
  line $VER "Install afpd.conf to $S"
  backup "$S"
  echo -n "- -transall -nouservol -setuplog \"default log_info" >"$S"
  echo -n " /opt/var/log/afpd.log\" -defaultvol" >>"$S"
  echo -n " /opt/etc/netatalk/AppleVolumes.default -systemvol" >>"$S"
  echo -n " /opt/etc/netatalk/AppleVolumes.system -noddp -uamlist" >>"$S"
  echo    " uams_dhx2.so" >>"$S"

  if logShow 5; then
    log $DAT "# $S:"
    cat "$S"
  fi
  line $VER ""
}

installAFPDMountScript() {
  line $VER "Install afpd-mount to /jffs/scripts"

  P="$SCRIPTS/post-mount"
  A="$SCRIPTS/afpd-mount"
  backup "$P"
  backup "$A"

  if [ ! -f "$P" ]; then
    echo "#!/bin/sh" >"$P"
  fi
  sed -i '/afpd-mount/d' "$P"
  echo "$A" >>"$P"
  line $VER "$A"
  cat >"$A" <<EOS
#!/bin/sh
AFPD_USER="$1"
TARGET="/opt/etc/netatalk/AppleVolumes.default"

cp "\$TARGET" "\$TARGET.bak"
echo "-" >"\$TARGET"

devName() {
  DEV="\$1"

  NAME="\$(/opt/sbin/blkid -o value -s LABEL \$DEV)"

  if [ "\$NAME" = "" ]; then
    NAME="\$DEV{1:5}"
  fi

  echo "\$NAME"
  return 0
}

addShare() {
  SHARE="\$1"; NAME="\$2"; USERS="\$3"; OPTIONS="\$4"; VOLSIZELIMIT="\$5"
  echo "\$SHARE :: \$NAME :: \$USERS :: \$OPTIONS :: \$VOLSIZELIMIT"
  echo "Create share: \$SHARE (\$NAME)"

  ADD="\$SHARE \"\$NAME\" "
  ADD="\$ADD cnidscheme:dbd options:usedots,upriv\$OPTIONS"
  if [ "\$VOLSIZELIMIT" != "" ]; then
    ADD="\$ADD volsizelimit:\$VOLSIZELIMIT"
  fi
  ADD="\$ADD allow:\"\$USERS\""

  echo "# \$ADD"
  echo "\$ADD" >>"\$TARGET"
}

mount | grep "/dev/sd" | while read L; do
  DEV=\$(echo "\$L" | awk '{print \$1}')
  SHARE=\$(echo "\$L" | awk '{print \$3}')
  NAME=\$(devName \$DEV)
  addShare "\$SHARE" "\$NAME" "\$AFPD_USER"
done

if [ -x "/jffs/configs/timemachine.vars" ]; then
  echo "Add Time Machine share"
  ( . /jffs/configs/timemachine.vars
    if [ "\$TIME_LOC" = "" ]; then
      echo "Time Machine not enabled"
      return 0
    fi
    if [ "\$TIME_NAME" = "" ]; then
      TIME_NAME=$(basename "\$TIME_LOC")
    else
      addShare "\$TIME_LOC" "\$TIME_NAME" "\$AFPD_USER" ",tm" "\$TIME_SIZE"
    fi
  )
fi

/opt/etc/init.d/S27afpd reconfigure
EOS
  if logShow 4; then
    grep -n "" "$A"
  fi
  chmod +x "$A"
  sh "$A" || true

  line $VER ""
}

writeAvahiService() {
  SERVICES="$BASE/services"
  FILE="$SERVICES/$1.service"
  backup "$FILE"
  log $INF "# $FILE"

  CONFPREFIX="<?xml version=\"1.0\" standalone='no'?><!--*-nxml-*-->
<!DOCTYPE service-group SYSTEM \"avahi-service.dtd\">
<service-group>
  <name replace-wildcards=\"yes\">%h</name>"
  CONFMAIN="$2"
  CONFSUFFIX="</service-group>"
  echo -e "$CONFPREFIX\n$CONFMAIN\n$CONFSUFFIX\n" >"$FILE"
  if logShow 5; then
    grep -n "" "$FILE"
  fi
}

avahiInstallConf() {
  line $INF "Installing Avahi configuration"
  BASE="/opt/etc/avahi"
  line $VER "To $BASE"
  CONF="$BASE/avahi-daemon.conf"
  backup "$CONF"

  HOST="$(nvram get computer_name)"
  IP="$(nvram get lan_ipaddr)"
  LAN_DOMAIN=$(nvram get lan_domain)
  LAN_DOMAIN=${LAN_DOMAIN:=local}

  log $VER "# CONF"
  cat >"$CONF" <<EOS
[server]
host-name=$HOST
domain-name=$LAN_DOMAIN
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
publish-dns-servers=$IP
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
  if logShow 5; then
    cat "$CONF"
  fi

  for FILE in "$BASE/services/"*.service; do
    echo "Delete $FILE"
    backup $FILE
    rm $FILE
  done

  go "Enable Apple File Protocol (netatalk / afpd) broadcast?" &&
    writeAvahiService "afpd" "
  <service>
    <type>_afpovertcp._tcp</type>
    <port>548</port>
  </service>
  <service>
    <type>_device-info._tcp</type>
    <port>0</port>
    <txt-record>model=AirPort</txt-record>
  </service>"

  # go "Enable Secure Shell (SSH) broadcast?" &&
  #   writeAvahiService "ssh" "
  # <service>
  #   <type>_ssh._tcp</type>
  #   <port>22</port>
  # </service>"

  # go "Enable Routers Homepage (HTTP) broadcast?" &&
  #   writeAvahiService "http" "
  # <service>
  #   <type>_http._tcp</type>
  #   <port>80</port>
  # </service>"

  # go "Enable Windows File Sharing (Samba) broadcast?" &&
  #   writeAvahiService "samba" "
  # <service>
  #   <type>_smb._tcp</type>
  #   <port>139</port>
  # </service>"

  # go "Enable Network File System (NFS) broadcast?" &&
  #   writeAvahiService "nfs" "
  # <service>
  #   <type>_nfs._tcp</type>
  #   <port>2149</port>
  #   <txt-record>path=/tmp/etc/exports</txt-record>
  # </service>"

  go "Enable iTunes Library (DAAP) broadcast?" &&
    writeAvahiService "daap" "
  <service>
  <type>_daap._tcp</type>
  <port>3689</port>
  <txt-record>txtvers=1 iTShVersion=131073 Version=196610</txt-record>
  </service>

  <service>
  <type>_rsp._tcp</type>
  <port>3689</port>
  <txt-record>txtvers=1 iTShVersion=131073 Version=196610</txt-record>
  </service>"

  # go "Enable Digital Living Network Alliance (DLNA) broadcast?" &&
  #   writeAvahiService "dlna" "
  # <service>
  #   <type>_http._tcp</type>
  #   <port>8200</port>
  # </service>"

  /opt/etc/init.d/S42avahi-daemon restart
  line $INF ""
}

## save arguments in case we need them in a function
ARGS=$*

main
