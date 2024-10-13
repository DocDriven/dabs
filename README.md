# dabs - DocDriven's arch boostrapping script

Credit goes to Luke Smith's (LARBS)[https://github.com/LukeSmithxyz/LARBS] project, which was the base for this repository. The key differences are that arbs
* is more minimalistic,
* does not feature a fancy whiptail design but console outputs,
* and removes the need for installing neovim plugins due to
setup using lazy instead of packer.

Also, I fixed some issues I was having with the group ownerships introduced by the original script, which made all user directories part of the wheel group. All files have the <username>:<username> ownership now, as it should be.
