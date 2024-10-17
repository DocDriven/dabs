# dabs - DocDriven's arch boostrapping script

Credit goes to Luke Smith's [LARBS](https://github.com/LukeSmithxyz/LARBS) project, which was the base for this repository. The key differences are that dabs
* is more minimalistic,
* does not feature a fancy whiptail design but console outputs,
* and removes the need for installing neovim plugins due to
setup using lazy instead of packer.

Also, I fixed some issues I was having with the group ownerships introduced by the original script, which made all user directories part of the wheel group. All files have the ´username:username´ ownership now, as it should be.

## Usage

After [installing basic Arch](https://wiki.archlinux.org/title/Installation_guide) on your system, log into an account (usually root) and make sure that you have a working internet connection. Then, execute with root rights

    ./dabs.sh

You will be prompted for a username and a password. After that, the installation will proceed without further inputs.

As this script uses my dotfiles, you might have to edit a few files:
* /home/username/.dotfiles/config/polybar/config.ini
  * set ´interface´ for the wireless-network module to the correct interface (or diable it entirely)
  * set ´hwmon´ for the temperature-cpu module to the correct path
* /home/username/.dotfiles/config/x11/xprofile
  * save your desired wallpaper to /home/username/.config/bg/wallpaper.jpg OR
  * change the path so that it references your desired wallpaper

