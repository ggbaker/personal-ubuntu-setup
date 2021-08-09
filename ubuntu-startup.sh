#!/usr/bin/env bash
### Configuration script for a new ubuntu installation
### Gary Baker

## Exit script automatically if unhandled error
set -euo pipefail


###################################################
## Set user info

USER=$(whoami)
EMAIL="gary.baker@wisc.edu"

## Set device being installed
# Set from stdin if provided. Otherwise ask
if [[ "\$1" == "laptop" || "\$1" == "desktop" ]]; then
    DEVICE=\$1
    echo "Configuring for a \$1 install"
    else
    read -p "laptop or desktop install? " DEVICE
    [[ "$DEVICE" == "laptop" || "$DEVICE" == "desktop" ]] || { echo "invalid input"; exit 1; }
fi


###################################################
## Install some random utilities

# Apt installs
sudo apt-get install -y htop tmux fzf mosh fonts-powerline ispell \
    shellcheck graphviz sqlite3 gnome-tweaks chrome-gnome-shell \
    libgpgme-dev pcscd scdaemon yubikey-manager xclip thunderbird \
    curl neovim

## Installs with no repo
# lsd - better ls
cd $HOME/Downloads
wget https://github.com/Peltoche/lsd/releases/download/0.20.1/lsd_0.20.1_amd64.deb
sudo dpkg -i ./lsd_0.20.1_amd64.deb
rm lsd_0.20.1_amd64.deb
cd $HOME

## Snap installs
snap install spotify
snap install jabref


###################################################
## Install and setup git

# Signing key will be set by the config files set later
sudo apt-get install -y git
git config --global user.name "Gary Baker"
git config --global user.email $EMAIL

# Generate ssh key for github login if it doesn't already exist
if ! [[ -f $HOME/.ssh/github ]]; then
    ssh-keygen -t ed25519 -C $EMAIL -f $HOME/.ssh/github -N ""
fi
ssh-add $HOME/.ssh/github
# print public key for copying
cat $HOME/.ssh/github.pub | xclip -selection clipboard
cat $HOME/.ssh/github.pub

CONTINUE="n"
while ! [[  "$CONTINUE" == "y" ]]; do
	read -n 1 -p "Paste (should already be in clipboard) the above to github. \
		Once done, press y to continue: " CONTINUE
done

# Check if the authorization worked. Try 3 times
for try in { 1..3 }; do
    ssh -T git@github.com || ERROR=$?
    # Previous returns error code 1 if auth successful
    if [[ $ERROR == 1 ]]; then
        break
    else
        echo "Github authorization failed. Did you copy the key?"
        cat $HOME/.ssh/github.pub
        read -n 1 -p "Check github, and press any key to continue "
    fi
done
[[ $try == 3 ]] && exit 1 # quit if fails 3 times


###################################################
## get config files for the appropriate install

cd $HOME
rm -rf .cfg || true
if [[ "$DEVICE" == "desktop" ]]; then
    git clone --bare git@github.com:ggbaker/dot-files .cfg
fi
if [[ "$DEVICE" == "laptop" ]]; then
    git clone --branch laptop --bare git@github.com:ggbaker/dot-files .cfg
fi
# load config files into home directory
git --git-dir=$HOME/.cfg --work-tree=$HOME checkout -f
# clone submodules
git --git-dir=$HOME/.cfg --work-tree=$HOME submodule update --init --recursive

###################################################
## Install emacs (from source)

# Get dependencies
sudo apt-get install -y autoconf make gcc texinfo libgtk-3-dev libxpm-dev \
    libjpeg-dev libgif-dev libgif-dev libtiff5-dev libgnutls28-dev \
    libncurses5-dev libjansson-dev libharfbuzz-bin imagemagick \
    libmagickwand-dev libxaw7-dev ripgrep fd-find

# Installing emacs from source is slow. Ask to confirm
read -n 1 -p "Install emacs? y/n "
if [[ "${REPLY}" == "y" ]]; then
    cd $HOME/Downloads
    rm -rf emacs 2> /dev/null || true # remove emacs folder if already exists
    git clone --depth 1 --single-branch --branch emacs-27 https://github.com/emacs-mirror/emacs.git
    cd emacs
    ./autogen.sh
    ./configure --with-json --with-modules --with-harfbuzz --with-compress-install --with-threads \
        --with-included-regex --with-x-toolkit=lucid --with-zlib --without-sound \
        --with-imagemagick --without-mailutils
    make
    sudo make install

    # Install doom emacs
    cd $HOME
    rm -rf .emacs.d 2> /dev/null || true # remove emacs config dir if already exists
    git clone --depth 1 https://github.com/hlissner/doom-emacs ~/.emacs.d
    .emacs.d/bin/doom install

    # Install personal config for doom
    rm -rf .doom.d 2> /dev/null || true # remove doom config dir if already exists
    git clone git@github.com:ggbaker/doom-emacs-config ~/.doom.d
fi


###################################################
## Shell configuration

# install zsh
sudo apt-get -y install zsh
sudo chsh -s /bin/zsh $USER      # set zsh as default shell


###################################################
## Install keybase

cd $HOME/Downloads
curl --remote-name https://prerelease.keybase.io/keybase_amd64.deb
sudo apt-get install ./keybase_amd64.deb
run_keybase
rm keybase_amd64.deb
cd $HOME

###################################################
## Install fonts and tex

# Installing tex is slow. Ask to confirm
read -n 1 -p "Install tex? y/n "
if [[ "${REPLY}" == "y" ]]; then
    sudo apt-get install -y texlive-full
fi