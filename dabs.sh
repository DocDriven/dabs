#!/bin/sh

dotfilesrepo="https://github.com/DocDriven/dotfiles.git"
progsfile="https://raw.githubusercontent.com/DocDriven/dabs/master/progs.csv"
aurhelper="yay"
repobranch="master"
export TERM=ansi

name="username"

installpkg() {
	pacman --noconfirm --needed -S "$1" >/dev/null 2>&1
}

info() {
	# Log to stdout
	printf "%s\n" "$1"
}

error() {
	# Log to stderr and exit with failure.
	printf "%s\n" "$1" >&2
	exit 1
}

adduserandpass() {
	# Adds user `name` with password `pass`
	read -s -p "Enter password: " pass1
	echo
	read -s -p "Confirm password: " pass2
	echo

	if [ "$pass1" != "$pass2" ]; then
		error "passwords do no match. exiting."
	fi

	info "adding user $name and setting password..."
	useradd -m -g wheel -s /bin/zsh "$name" >/dev/null 2>&1 ||
		usermod -a -G wheel "$name" &&
		mkdir -p /home/"$name" &&
		chown "$name":wheel /home/"$name"
	export repodir="/home/$name/.local/src"
	mkdir -p "$repodir"
	chown -R "$name":wheel "$(dirname "$repodir")"
	echo "$name:$pass1" | chpasswd
	unset pass1 pass2
	info "done."
}

refreshkeys() {
	case "$(readlink -f /sbin/init)" in
	*systemd*)
		info "refreshing Arch keyring..."
		pacman --noconfirm -S archlinux-keyring >/dev/null 2>&1
		info "done."
		;;
	*)
		info "enabling Arch repositories..."
		pacman --noconfirm --needed -S \
			artix-keyring artix-archlinux-support >/dev/null 2>&1
		grep -q "^\[extra\]" /etc/pacman.conf ||
			echo "[extra] Include = /etc/pacman.d/mirrorlist-arch" >>/etc/pacman.conf
		pacman -Sy --noconfirm >/dev/null 2>&1
		pacman-key --populate archlinux >/dev/null 2>&1
		info "done."
		;;
	esac
}

manualinstall() {
	# Installs $1 manually. Used only for AUR helper here.
	# Should be run after repodir is created and var is set.
	pacman -Qq "$1" && return 0
	info "installing $1 manually..."
	sudo -u "$name" mkdir -p "$repodir/$1"
	sudo -u "$name" git -C "$repodir" clone --depth 1 --single-branch \
		--no-tags -q "https://aur.archlinux.org/$1.git" "$repodir/$1" ||
		{
			cd "$repodir/$1" || return 1
			sudo -u "$name" git pull --force origin master
		}
	cd "$repodir/$1" || exit 1
	sudo -u "$name" \
		makepkg --noconfirm -si >/dev/null 2>&1 || return 1
	info "done."
}

maininstall() {
	# install program from Arch main repo.
	info "[$n / $total] installing $1 ($2) from official repository"
	installpkg "$1"
	info "done."
}

gitmakeinstall() {
	# build program from git repository with make.
	progname="${1##*/}"
	progname="${progname%.git}"
	tempdir="$repodir/$progname"
	info "[$n / $total] installing $progname ($2) from git sources"
	sudo -u "$name" git -C "$repodir" clone --depth 1 --single-branch \
		--no-tags -q "$1" "$tempdir" ||
		{
			cd "$tempdir" || return 1
			sudo -u "$name" git pull --force origin master
		}
	cd "$tempdir" || exit 1
	make >/dev/null 2>&1
	make install >/dev/null 2>&1
	cd /tmp || return 1
	info "done."
}

aurinstall() {
	# install program from AUR
	info "[$n / $total] installing $1 ($2) from AUR"
	echo "$aurinstalled" | grep -q "^$1$" && return 1
	sudo -u "$name" $aurhelper -S --noconfirm "$1" >/dev/null 2>&1
	info "done."
}

pipinstall() {
	# install program with pip
	info "[$n / $total] installing $1 ($2) with pip"
	[ -x "$(command -v "pip")" ] || installpkg python-pip >/dev/null 2>&1
	yes | pip install "$1"
	info "done."
}

installationloop() {
	([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) ||
		curl -Ls "$progsfile" | sed '/^#/d' >/tmp/progs.csv
	total=$(wc -l </tmp/progs.csv)
	aurinstalled=$(pacman -Qqm)
	while IFS=, read -r tag program comment; do
		n=$((n + 1))
		echo "$comment" | grep -q "^\".*\"$" &&
			comment="$(echo "$comment" | sed -E "s/(^\"|\"$)//g")"
		case "$tag" in
		"A") aurinstall "$program" "$comment" ;;
		"G") gitmakeinstall "$program" "$comment" ;;
		"P") pipinstall "$program" "$comment" ;;
		*) maininstall "$program" "$comment" ;;
		esac
	done </tmp/progs.csv
}

installdotfiles() {
	# pull and install dotfiles from $1 to dir $2 with branch $3.
	info "pulling dotfiles from $1..."	
	[ -z "$3" ] && branch="master" || branch="$repobranch"
	tempdir=$(mktemp -d)
	[ ! -d "$2" ] && mkdir -p "$2"
	chown "$name":wheel "$tempdir" "$2"
	sudo -u "$name" git clone \
		--depth 1 \
		--single-branch \
		--no-tags \
		-q \
		--recursive \
		-b "$branch" \
		--recurse-submodules \
		"$1" "$tempdir"
	sudo -u "$name" cp -rfT "$tempdir" "$2"
	pushd "$2" > /dev/null || error "pushd failed. exiting."
	./install
	popd > /dev/null || error "popd failed. exiting."
	info "done."
}

# check if user is root
if [ "$EUID" -ne 0 ]; then
    error "script must be run as root. exiting."
fi

# check if pacman is installed
if ! command -v pacman &> /dev/null; then
    error "pacman is not installed. exiting."
fi

# check for internet connection
if ! ping -c 1 8.8.8.8 &> /dev/null; then
    error "currently not connected to the internet. exiting."
fi

# check username. requires username to
#   start with lowercase letter or underscore
#   contain only lowercase letters, digits, underscores and hyphens
if ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; then
    error "invalid username. exiting."
fi

# abort if user already exists
if id -u "$name" >/dev/null 2>&1; then
    error "user already exists. exiting."
fi

# refresh Arch keyrings
refreshkeys || error "Arch keyring refresh failed. exiting."

# install tools for building packages
for x in curl ca-certificates base-devel git ntp zsh dash; do
	info "installing $x..."
	installpkg "$x"
	info "done."
done

info "synchronizing time..."
ntpd -q -g >/dev/null 2>&1
info "done."

adduserandpass || error "error adding username and/or password. exiting."

# reset sudoers file
[ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers

# allow a temporary user to run sudo without password.
# necessary to install AUR programs
trap 'rm -f /etc/sudoers.d/dabs-temp' HUP INT QUIT TERM PWR EXIT
echo "%wheel ALL=(ALL) NOPASSWD: ALL
Defaults:%wheel,root runcwd=*" >/etc/sudoers.d/dabs-temp

# make pacman colorful, concurrent downloads and Pacman eye-candy
grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
sed -Ei "s/^#(ParallelDownloads).*/\1 = 5/;/^#Color$/s/#//" /etc/pacman.conf

# use all cores for compilation
sed -i "s/-j2/-j$(nproc)/;/^#MAKEFLAGS/s/^#//" /etc/makepkg.conf

manualinstall $aurhelper || error "installing AUR helper failed. exiting."

# make sure .*-git AUR packages get updated automatically.
$aurhelper -Y --save --devel

# install programs listed in the progs.csv according to the first column.
# only run after a privileged user has been created and build dependencies
# have been installed.
installationloop

# download dotfiles and install them by running the dotbot install script
installdotfiles "$dotfilesrepo" "/home/$name/.dotfiles" "$repobranch"

# disable PC speaker kernel module
rmmod pcspkr
echo "blacklist pcspkr" >/etc/modprobe.d/nobeep.conf

# change default shell to zsh for the user
chsh -s /bin/zsh "$name" >/dev/null 2>&1
sudo -u "$name" mkdir -p "/home/$name/.cache/zsh/"

# allow wheel users to sudo with password and allow several system commands
# (like `shutdown` to run without password).
echo "%wheel ALL=(ALL:ALL) ALL" >/etc/sudoers.d/00-larbs-wheel-can-sudo
echo "%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/pacman -Syyuw --noconfirm,/usr/bin/pacman -S -y --config /etc/pacman.conf --,/usr/bin/pacman -S -y -u --config /etc/pacman.conf --" >/etc/sudoers.d/01-larbs-cmds-without-password
echo "Defaults editor=/usr/bin/nvim" >/etc/sudoers.d/02-larbs-visudo-editor
mkdir -p /etc/sysctl.d
echo "kernel.dmesg_restrict = 0" > /etc/sysctl.d/dmesg.conf

# cleanup
rm -f /etc/sudoers.d/dabs-temp
