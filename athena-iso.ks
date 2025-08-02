# athena-iso.ks

lang en_US.UTF-8
keyboard us
timezone Europe/Rome
selinux --enforcing
firewall --enabled --service=mdns
xconfig --startxonboot
zerombr
clearpart --all
part / --size 5120 --fstype ext4
services --enabled=NetworkManager,qemu-guest-agent,vboxservice,vmtoolsd --disabled=sshd
network --bootproto=dhcp --device=link --activate
rootpw --lock --iscrypted locked
shutdown

# Repositories used by Kickstart installation. They don't persist in the Live Environment
repo --name=fedora --mirrorlist=https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-$releasever&arch=$basearch
repo --name=updates --mirrorlist=https://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f$releasever&arch=$basearch
#repo --name=updates-testing --mirrorlist=https://mirrors.fedoraproject.org/mirrorlist?repo=updates-testing-f$releasever&arch=$basearch
url --mirrorlist=https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-$releasever&arch=$basearch
repo --name=athenaos --baseurl=https://copr-be.cloud.fedoraproject.org/results/@athenaos/athenaos/fedora-$releasever-$basearch/
repo --name=nix --baseurl=https://copr-be.cloud.fedoraproject.org/results/petersen/nix/fedora-$releasever-$basearch/
# Note that if one of the repo URLs are wrong, the job process will stuck on "anaconda" command

# spin was failing to compose due to lack of space, so bumping the size.
#part / --size 10240

user --name=liveuser --groups=wheel --password='athena' --plaintext

%packages
#######################################################
###                  BASIC PACKAGES                 ###
#######################################################

kernel
kernel-modules
kernel-modules-extra
kernel-headers

# The point of a live image is to install
# Tools provided by these anaconda packages are used to implement ISO check and other useful packages for ISO Live environment
@anaconda-tools
anaconda-install-env-deps

# Anaconda has a weak dep on this and we don't want it on livecds, see
# https://fedoraproject.org/wiki/Changes/RemoveDeviceMapperMultipathFromWorkstationLiveCD
-fcoe-utils
-device-mapper-multipath
-sdubby

# Without this, initramfs generation during live image creation fails: #1242586
dracut-live

# anaconda needs the locales available to run for different locales
glibc-all-langpacks

# provide the livesys scripts
livesys-scripts

alsa-sof-firmware
cracklib-dicts # passwd policy checks
dhcpcd
dialog
grub2
iproute
iputils
linux-firmware
lvm2
mesa-dri-drivers
mesa-vulkan-drivers
mtools
nano
net-tools
NetworkManager
network-manager-applet
nfs-utils
nss-mdns
ntpsec
os-prober
pavucontrol
pipewire
pipewire-pulseaudio
pv
rsync
squashfs-tools
sudo
syslinux
terminus-fonts-console
testdisk
usbutils
vim
wireplumber
wpa_supplicant
xorg-x11-server-Xorg
xorg-x11-xinit

#######################################################
###                  WiFi Firmware                  ###
#######################################################

NetworkManager-wifi
atheros-firmware
b43-fwcutter
b43-openfwwf
brcmfmac-firmware
iwlegacy-firmware
iwlwifi-dvm-firmware
iwlwifi-mvm-firmware
libertas-firmware
mt7xxx-firmware
nxpwireless-firmware
realtek-firmware
tiwilink-firmware
atmel-firmware
zd1211-firmware

#######################################################
###                   VPN Plugins                   ###
#######################################################
NetworkManager-sstp
NetworkManager-l2tp
NetworkManager-openconnect
NetworkManager-openvpn
NetworkManager-pptp
NetworkManager-strongswan
NetworkManager-vpnc

#######################################################
###                      FONTS                      ###
#######################################################
google-noto-color-emoji-fonts
jetbrains-mono-fonts-all

#######################################################
###                    UTILITIES                    ###
#######################################################

bat
espeak-ng
fastfetch
git
gparted
lsd
netcat
orca
polkit
ufw
wget2-wget
which
xclip
zoxide

#######################################################
###                ATHENA REPOSITORY                ###
#######################################################

aegis
aegis-tui
athena-bash
athena-config
athena-graphite-design
athena-kitty-config
#athena-powershell-config
athena-tweak-tool
athena-tmux-config
athena-vscodium-themes
athena-welcome
athena-xfce-refined
athenaos-release
#fedora-release
#athenaos-release-identity-basic
devotio
firefox-blackice

#######################################################
###                 LIVE ENVIRONMENT                ###
#######################################################
hyperv-tools
nix
open-vm-tools
pacman
qemu-guest-agent
rate-mirrors
spice-vdagent
virtualbox-guest-additions
xorg-x11-drv-vmware

%end

%post
# VARIABLES
USERNAME="liveuser"

# Enable livesys services
systemctl enable livesys.service
systemctl enable livesys-late.service
systemctl enable nix-daemon.service

# enable tmpfs for /tmp
systemctl enable tmp.mount

# make it so that we don't do writing to the overlay for things which
# are just tmpdirs/caches
# note https://bugzilla.redhat.com/show_bug.cgi?id=1135475
cat >> /etc/fstab << EOF
vartmp   /var/tmp    tmpfs   defaults   0  0
EOF

# work around for poor key import UI in PackageKit
rm -f /var/lib/rpm/__db*
echo "Packages within this LiveCD"
rpm -qa --qf '%{size}\t%{name}-%{version}-%{release}.%{arch}\n' |sort -rn
# Note that running rpm recreates the rpm db files which aren't needed or wanted
rm -f /var/lib/rpm/__db*

# go ahead and pre-make the man -k cache (#455968)
/usr/bin/mandb

# make sure there aren't core files lying around
rm -f /core*

# remove random seed, the newly installed instance should make it's own
rm -f /var/lib/systemd/random-seed

# convince readahead not to collect
# FIXME: for systemd

echo 'File created by kickstart. See systemd-update-done.service(8).' \
    | tee /etc/.updated >/var/.updated

# Drop the rescue kernel and initramfs, we don't need them on the live media itself.
# See bug 1317709
rm -f /boot/*-rescue*

# Disable network service here, as doing it in the services line
# fails due to RHBZ #1369794
systemctl disable network

# Remove machine-id on pre generated images
rm -f /etc/machine-id
touch /etc/machine-id

# etc/default/grub

cat > /etc/default/grub <<'EOF'
# GRUB boot loader configuration

GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3 audit=0 nvme_load=yes zswap.enabled=0 fbcon=nodefer tmpfs.size=4096m nowatchdog"
GRUB_CMDLINE_LINUX=""

# Preload both GPT and MBR modules so that they are not missed
GRUB_PRELOAD_MODULES="part_gpt part_msdos"

# Uncomment to enable booting from LUKS encrypted devices
#GRUB_ENABLE_CRYPTODISK=y

# Set to 'countdown' or 'hidden' to change timeout behavior,
# press ESC key to display menu.
#GRUB_TIMEOUT_STYLE=menu

# Uncomment to use basic console
GRUB_TERMINAL_INPUT=console

# Uncomment to disable graphical terminal
#GRUB_TERMINAL_OUTPUT=console

# The resolution used on graphical terminal
# note that you can use only modes which your graphic card supports via VBE
# you can see them in real GRUB with the command `vbeinfo'
GRUB_GFXMODE=1280x720

# Uncomment to allow the kernel use the same resolution used by grub
GRUB_GFXPAYLOAD_LINUX=keep

# Uncomment if you want GRUB to pass to the Linux kernel the old parameter
# format "root=/dev/xxx" instead of "root=/dev/disk/by-uuid/xxx"
#GRUB_DISABLE_LINUX_UUID=true

# Uncomment to disable generation of recovery mode menu entries
GRUB_DISABLE_RECOVERY=true

# Uncomment and set to the desired menu colors.  Used by normal and wallpaper
# modes only.  Entries specified as foreground/background.
#GRUB_COLOR_NORMAL="light-blue/black"
#GRUB_COLOR_HIGHLIGHT="light-cyan/blue"

# Uncomment one of them for the gfx desired, a image background or a gfxtheme
#GRUB_BACKGROUND="/usr/share/backgrounds/default/grub.png"
#GRUB_THEME="/usr/share/grub/themes/starfield/theme.txt"

# Uncomment to get a beep at GRUB start
#GRUB_INIT_TUNE="480 440 1"

# Uncomment to make GRUB remember the last selection. This requires
# setting 'GRUB_DEFAULT=saved' above. Change 0 into saved.
# Do not forget to 'update-grub' in a terminal to apply the new settings
#GRUB_SAVEDEFAULT="true"

# Uncomment to make grub stop using submenus
#GRUB_DISABLE_SUBMENU=y

# Check for other operating systems
GRUB_DISABLE_OS_PROBER=false
EOF

# Creating profile files directly on user home (and not on skel) because the account is created at the first stage of kickstart
# .bash_profile
cat > /home/${USERNAME}/.bash_profile <<'EOF'
#
# ~/.bash_profile
#
# xinit <session> will look for ~/.xinitrc content
if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
  # By autologin with no display manager, XDG_SESSION_TYPE will be set as tty
  # If the system does not recognize x11, some things like spice-vdagent for qemu
  # or the application of XFCE backgrounds by CLI could not work
  export XDG_SESSION_TYPE=x11
  startx ~/.xinitrc xfce4 &>/dev/null
fi
EOF

# .xinitrc
cat > /home/${USERNAME}/.xinitrc <<'EOF'
# Here Xfce is kept as default
session=${1:-xfce}

case $session in
    i3|i3wm           ) exec i3;;
    kde               ) exec startplasma-x11;;
    xfce|xfce4        ) exec startxfce4;;
    # No known session, try to run it as command
    *                 ) exec $1;;
esac
EOF

# autologin.conf
# Usage of EOF with no single quotes to expand USERNAME variable
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin ${USERNAME} --noclear %I \$TERM
EOF

# .bashrc
# The usage of 'EOF' with single-quotes prevent variable expansions
cat <<'EOF' | tee /etc/skel/.bashrc > /home/${USERNAME}/.bashrc
# ~/.bashrc

# Append "$1" to $PATH when not already in.
append_path () {
    case ":$PATH:" in
        *:"$1":*)
            ;;
        *)
            PATH="${PATH:+$PATH:}$1"
    esac
}
append_path "$HOME/bin"
append_path "$HOME/.local/bin"

### EXPORT ### Should be before the change of the shell
export EDITOR=/usr/bin/nvim
export VISUAL='nano'
export HISTCONTROL=ignoreboth:erasedups:ignorespace
HISTSIZE=100000
HISTFILESIZE=2000000
shopt -s histappend
export PAGER='most'

export TERM=xterm-256color
export SHELL=$(which bash)

export PAYLOADS="/usr/share/payloads"
export SECLISTS="$PAYLOADS/seclists"
export PAYLOADSALLTHETHINGS="$PAYLOADS/payloadsallthethings"
export FUZZDB="$PAYLOADS/fuzzdb"
export AUTOWORDLISTS="$PAYLOADS/autowordlists"
export SECURITYWORDLIST="$PAYLOADS/security-wordlist"

export MIMIKATZ="/usr/share/windows/mimikatz/"
export POWERSPLOIT="/usr/share/windows/powersploit/"

export ROCKYOU="$SECLISTS/Passwords/Leaked-Databases/rockyou.txt"
export DIRSMALL="$SECLISTS/Discovery/Web-Content/directory-list-2.3-small.txt"
export DIRMEDIUM="$SECLISTS/Discovery/Web-Content/directory-list-2.3-medium.txt"
export DIRBIG="$SECLISTS/Discovery/Web-Content/directory-list-2.3-big.txt"
export WEBAPI_COMMON="$SECLISTS/Discovery/Web-Content/api/api-endpoints.txt"
export WEBAPI_MAZEN="$SECLISTS/Discovery/Web-Content/common-api-endpoints-mazen160.txt"
export WEBCOMMON="$SECLISTS/Discovery/Web-Content/common.txt"
export WEBPARAM="$SECLISTS/Discovery/Web-Content/burp-parameter-names.txt"

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# --- One-time setup ---
if [[ $1 != no-repeat-flag && -z $NO_REPETITION ]]; then
  export NO_REPETITION=1
  fastfetch
fi

# Optional: Source Blesh if installed
[[ $1 != no-repeat-flag && -f /usr/share/blesh/ble.sh ]] && source /usr/share/blesh/ble.sh

# --- Bash completion ---
[[ $PS1 && -f /usr/share/bash-completion/bash_completion ]] && . /usr/share/bash-completion/bash_completion

# --- Aliases ---
if [ -f ~/.bash_aliases ]; then
  . ~/.bash_aliases
fi

# --- Shell behavior ---
shopt -s autocd
shopt -s cdspell
shopt -s cmdhist
shopt -s dotglob
shopt -s histappend
shopt -s expand_aliases

# --- ex (extractor helper) ---
ex () {
  if [ -f "$1" ]; then
    case "$1" in
      *.tar.bz2)   tar xjf "$1"   ;;
      *.tar.gz)    tar xzf "$1"   ;;
      *.bz2)       bunzip2 "$1"   ;;
      *.rar)       unrar x "$1"   ;;
      *.gz)        gunzip "$1"    ;;
      *.tar)       tar xf "$1"    ;;
      *.tbz2)      tar xjf "$1"   ;;
      *.tgz)       tar xzf "$1"   ;;
      *.zip)       unzip "$1"     ;;
      *.Z)         uncompress "$1";;
      *.7z)        7z x "$1"      ;;
      *.deb)       ar x "$1"      ;;
      *.tar.xz)    tar xf "$1"    ;;
      *.tar.zst)   tar xf "$1"    ;;
      *)           echo "'$1' cannot be extracted via ex()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}

# --- Git helpers ---
vimod () {
  vim -p $(git status -suall | awk '{print $2}')
}

virev () {
  local commit=${1:-HEAD}
  local rootdir=$(git rev-parse --show-toplevel)
  local sourceFiles=$(git show --name-only --pretty="format:" "$commit" | grep -v '^$')
  local toOpen=""
  for file in $sourceFiles; do
    local fullpath="$rootdir/$file"
    [ -e "$fullpath" ] && toOpen="$toOpen $fullpath"
  done
  if [ -z "$toOpen" ]; then
    echo "No files were modified in $commit"
    return 1
  fi
  vim -p $toOpen
}

gitPrompt() {
  command -v __git_ps1 > /dev/null && __git_ps1 " (%s)"
}

# --- cd up helper ---
cu () {
  local count=$1
  [[ -z "$count" ]] && count=1
  local upath=""
  for i in $(seq 1 $count); do
    upath+="../"
  done
  cd "$upath"
}

# --- Memory cleaning helper ---
buffer_clean(){
  free -h && sudo sh -c 'echo 1 > /proc/sys/vm/drop_caches' && free -h
}

# --- Fish-style dynamic prompt ---
set_bash_prompt() {
  local last_status=$?
  local tty_device=$(tty)
  local ip=$(ip -4 addr | grep -v '127.0.0.1' | grep -v 'secondary' \
    | grep -oP '(?<=inet\s)\d+(\.\d+){3}' \
    | sed -z 's/\n/|/g;s/|\$/\n/' \
    | rev | cut -c 2- | rev)

  local user="\u"
  local host="\h"
  local cwd="\w"
  local branch=""
  local hq_prefix=""
  local flame=""
  local robot=""

  if command -v git &>/dev/null; then
    branch=$(git symbolic-ref --short HEAD 2>/dev/null)
  fi

  if [[ "$tty_device" == /dev/tty* ]]; then
    hq_prefix="HQ─"
    flame=""
    robot="[>]"
  else
    hq_prefix="HQ🚀🌐"
    flame="🔥"
    robot="[👾]"
  fi

  if [[ $last_status -eq 0 ]]; then
    user_host="\[\e[1;34m\]($user@$host)\[\e[0m\]"
  else
    user_host="\[\e[1;31m\]($user@$host)\[\e[0m\]"
  fi

  local line1="\[\e[1;32m\]╭─[$hq_prefix\[\e[1;31m\]$ip\[\e[1;32m\]$flame]─$user_host"
  if [[ -n "$branch" ]]; then
    line1+="\[\e[1;33m\][ $branch]\[\e[0m\]"
  fi

  local line2="\[\e[1;32m\]╰─>$robot\[\e[1;36m\]$cwd \$\[\e[0m\]"

  PS1="${line1}\n${line2} "
}

PROMPT_COMMAND='set_bash_prompt'

EOF


# athenaos.repo
cat > /etc/yum.repos.d/athenaos.repo <<EOF
[athenaos]
name=Athena OS \$releasever - \$basearch
baseurl=https://download.copr.fedorainfracloud.org/results/@athenaos/athenaos/fedora-\$releasever-\$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=0
repo_gpgcheck=0
enabled=1
enabled_metadata=1
EOF

# microsoft.repo
cat > /etc/yum.repos.d/microsoft.repo <<EOF
[microsoft-fedora]
name=Microsoft Fedora \$releasever
baseurl=https://packages.microsoft.com/fedora/\$releasever/prod/
gpgcheck=0
repo_gpgcheck=0
enabled=1
gpgkey=https://packages.microsoft.com/fedora/\$releasever/prod/repodata/repomd.xml.key
EOF


echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/g_wheel
chmod 0440 /etc/sudoers.d/g_wheel


# Disable graphical target because, in ISO Live, Display Manager is not used.
# Otherwise Fedora Live might default to graphical.target, expecting gdm, and it could slow boot for a few seconds.
#systemctl set-default multi-user.target

%end

%post

# athena-mirrorlist
cat > /etc/pacman.d/athena-mirrorlist <<'EOF'
# Worldwide
Server = https://hub.athenaos.org/$repo/$arch
EOF

# athena-revoked
touch /usr/share/pacman/keyrings/athena-revoked

# athena-trusted
cat > /usr/share/pacman/keyrings/athena-trusted <<'EOF'
5A34EB551197A065F8A401AFA3F78B994C2171D5:4:
EOF

# athena.gpg
cat > /usr/share/pacman/keyrings/athena.gpg <<'EOF'
-----BEGIN PGP PUBLIC KEY BLOCK-----

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
YPdTv0KcDTDB4HRB+HiZoe3t+HXddwCx3oETeg==
=X2Oc
-----END PGP PUBLIC KEY BLOCK-----
EOF

# chaotic-revoked
cat > /usr/share/pacman/keyrings/chaotic-revoked <<'EOF'
3FFA0B5E092ED4095E26F69B8ADB4AEC585061CF
1A79037533A110285AE92EF4FAF4946E8D60D074
E732131CAF3C03724EF141A0749E88C8EC38D662
EOF

# chaotic-trusted
cat > /usr/share/pacman/keyrings/chaotic-trusted <<'EOF'
EF925EA60F33D0CB85C44AD13056513887B78AEB:4:
1F0716DC94015CAC77FA65B619A2282AFCA8A81E:4:
67BF8CA6DA181643C9723B4ED6C9442437365605:4:
EOF

# chaotic.gpg
cat > /usr/share/pacman/keyrings/chaotic.gpg <<'EOF'
-----BEGIN PGP PUBLIC KEY BLOCK-----

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
=T5nV
-----END PGP PUBLIC KEY BLOCK-----
-----BEGIN PGP PUBLIC KEY BLOCK-----

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
Axzd9A5vN54=
=JHlU
-----END PGP PUBLIC KEY BLOCK-----
-----BEGIN PGP PUBLIC KEY BLOCK-----

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
rVZx6wYz0qCUl1xwEbPkgIdw3rCiEPaseCQ=
=wuJa
-----END PGP PUBLIC KEY BLOCK-----
-----BEGIN PGP PUBLIC KEY BLOCK-----

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
=k+Zf
-----END PGP PUBLIC KEY BLOCK-----
-----BEGIN PGP PUBLIC KEY BLOCK-----

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
oQ0=
=Bkh0
-----END PGP PUBLIC KEY BLOCK-----
-----BEGIN PGP PUBLIC KEY BLOCK-----

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
=LIbz
-----END PGP PUBLIC KEY BLOCK-----
EOF

# pacman.conf
cat > /etc/pacman.conf <<'EOF'
#
# /etc/pacman.conf
#
# See the pacman.conf(5) manpage for option and repository directives

#
# GENERAL OPTIONS
#
[options]
# The following paths are commented out with their default values listed.
# If you wish to use different paths, uncomment and update the paths.
#RootDir     = /
#DBPath      = /var/lib/pacman/
#CacheDir    = /var/cache/pacman/pkg/
#LogFile     = /var/log/pacman.log
#GPGDir      = /etc/pacman.d/gnupg/
#HookDir     = /etc/pacman.d/hooks/
HoldPkg     = pacman glibc
#XferCommand = /usr/bin/curl -L -C - -f -o %o %u
#XferCommand = /usr/bin/wget --passive-ftp -c -O %o %u
#CleanMethod = KeepInstalled
Architecture = auto

# Pacman won't upgrade packages listed in IgnorePkg and members of IgnoreGroup
#IgnorePkg   =
#IgnoreGroup =

#NoUpgrade   =
#NoExtract   =

# Misc options
#UseSyslog
#Color
#NoProgressBar
CheckSpace
#VerbosePkgLists
ParallelDownloads = 5

# By default, pacman accepts packages signed by keys that its local keyring
# trusts (see pacman-key and its man page), as well as unsigned packages.
SigLevel    = Required DatabaseOptional
LocalFileSigLevel = Optional
#RemoteFileSigLevel = Required

# NOTE: You must run pacman-key --init before first using pacman; the local
# keyring can then be populated with the keys of all official Arch Linux
# packagers with pacman-key --populate archlinux.

#
# REPOSITORIES
#   - can be defined here or included from another file
#   - pacman will search repositories in the order defined here
#   - local/custom mirrors can be added here or in separate files
#   - repositories listed first will take precedence when packages
#     have identical names, regardless of version number
#   - URLs will have $repo replaced by the name of the current repo
#   - URLs will have $arch replaced by the name of the architecture
#
# Repository entries are of the format:
#       [repo-name]
#       Server = ServerName
#       Include = IncludePath
#
# The header [repo-name] is crucial - it must be present and
# uncommented to enable the repo.
#

# The testing repositories are disabled by default. To enable, uncomment the
# repo name header and Include lines. You can add preferred servers immediately
# after the header, and they will be used before the default mirrors.

[athena]
Include = /etc/pacman.d/athena-mirrorlist
#Server = https://hub.athenaos.org/$repo/$arch

#[core-testing]
#Include = /etc/pacman.d/mirrorlist

[core]
Include = /etc/pacman.d/mirrorlist

#[extra-testing]
#Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

# If you want to run 32 bit applications on your x86_64 system,
# enable the multilib repositories as required here.

#[multilib-testing]
#Include = /etc/pacman.d/mirrorlist

[multilib]
Include = /etc/pacman.d/mirrorlist

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist

# An example of a custom package repository.  See the pacman manpage for
# tips on creating your own repositories.
#[custom]
#SigLevel = Optional TrustAll
#Server = file:///home/custompkgs
EOF
%end
