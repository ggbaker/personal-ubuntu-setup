#!/usr/bin/env bash
### Configuration script for a new ubuntu installation
### Gary Baker

## Exit script automatically if unhandled error
set -euo pipefail

# Save current working dir
WORKINGDIR=$(pwd)
# Get location of script
SCRIPTDIR=$(cd $(dirname ${BASH_SOURCE[0]}) &> /dev/null && pwd)

###################################################
## Set user info

USER=$(whoami)
EMAIL="gary.baker@wisc.edu"


###################################################
## Choose what to setup

read -n 1 -ep "Complete install? (y/n)"
if [[ "${REPLY}" == "y" ]]; then
    read -p "Configure for which device? (laptop/desktop) " DEVICE
else
    read -n 1 -ep "Install smaller packages? (y/n) " APT
    read -n 1 -ep "Configure github ssh key? (y/n) " GITHUB
    read -ep "Install config files for which device? (laptop, desktop, n) " DEVICE
    read -n 1 -ep "Configure thinkfan and power management for x1 nano? (y/n) " FAN
    read -n 1 -ep "Install emacs? (y/n) " EMACS
    read -n 1 -ep "Install tex? (y/n) " TEX
    read -n 1 -ep "Install fonts? (y/n) " FONTS
fi


###################################################
## Install some random utilities

if [[ "$APT" = "y" ]]; then
    # Apt installs
    sudo apt-get install -y htop tmux fzf mosh fonts-powerline ispell \
        shellcheck graphviz sqlite3 gnome-tweaks chrome-gnome-shell \
        libgpgme-dev pcscd scdaemon yubikey-manager xclip thunderbird \
        curl vim mc
    # Install vim-plug for vim configuration
    curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

    ## Installs with no repo
    # lsd - better ls
    wget https://github.com/Peltoche/lsd/releases/download/0.20.1/lsd_0.20.1_amd64.deb
    sudo dpkg -i ./lsd_0.20.1_amd64.deb
    rm lsd_0.20.1_amd64.deb

    ## Install keybase
    curl --remote-name https://prerelease.keybase.io/keybase_amd64.deb
    sudo apt-get install ./keybase_amd64.deb
    run_keybase
    rm keybase_amd64.deb

    ## Snap installs
    sudo snap install spotify
    sudo snap install jabref
fi


###################################################
## Install and setup git

if [[ "$GITHUB" == "y" ]]; then
    sudo apt-get install -y git
    # Signing key will be set by the config files set later
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
fi


###################################################
## get config files for the appropriate install

if [[ "$DEVICE" == "laptop" ]] || [[ "$DEVICE" == "desktop" ]]; then
    rm -rf .cfg || true
    git clone --bare git@github.com:ggbaker/dot-files .cfg
    # load config files into home directory
    git --git-dir=$HOME/.cfg --work-tree=$HOME checkout -f
    # clone submodules
    git --git-dir=$HOME/.cfg --work-tree=$HOME submodule update --init --recursive

    ## Shell configuration
    # install zsh
    sudo apt-get -y install zsh
    sudo chsh -s /bin/zsh $USER      # set zsh as default shell
fi


###################################################
## Configure fan settings for X1 nano
## (Default lenovo settings are too agressive at low temps)
## Also install tlp for some better power tuning

if [[ "$FAN" == "y" ]]; then
    # install thinkfan
    sudo apt install thinkfan lm-sensors
    # enable thinkpad fan control
    sudo echo "options thinkpad_acpi fan_control=1" | sudo tee /etc/modprobe.d/thinkfan.conf
    sudo modprobe -rv thinkpad_acpi
    sudo modprobe -v thinkpad_acpi
    # copy config file
    sudo cp $SCRIPTDIR/thinkfan.yaml /etc/thinkfan.yaml
    # enable service
    sudo systemctl enable thinkfan

    # install tlp for power tuning
    sudo apt install acpi-call-dkms tlp
    # install auto-cpufreq for more tuning
    sudo snap install auto-cpufreq
    echo "Make sure to run sudo auto-cpufreq --install after setup completes"
fi


###################################################
## Install emacs (from source)

# Installing emacs from source is slow. Ask to confirm
if [[ "$EMACS" == "y" ]]; then
    # Get dependencies
    sudo apt-get install -y autoconf make gcc texinfo libgtk-3-dev libxpm-dev \
        libjpeg-dev libgif-dev libgif-dev libtiff5-dev libgnutls28-dev \
        libncurses5-dev libjansson-dev libharfbuzz-bin imagemagick \
        libmagickwand-dev libxaw7-dev ripgrep fd-find libvterm-dev zstd

    cd $HOME/Downloads
    rm -rf emacs 2> /dev/null || true # remove emacs folder if already exists
    git clone --depth 1 --single-branch --branch master https://github.com/emacs-mirror/emacs.git
    cd emacs
    ./autogen.sh
    ./configure --with-json --with-modules --with-harfbuzz --with-compress-install --with-threads \
        --with-included-regex --with-x-toolkit=lucid --with-zlib --without-sound \
        --with-imagemagick --without-mailutils
    make
    sudo make install
    # Leave emacs folder in Downloads in case needed later

    # Install doom emacs
    cd $HOME
    rm -rf .emacs.d 2> /dev/null || true # remove emacs config dir if already exists
    git clone --depth 1 https://github.com/hlissner/doom-emacs ~/.emacs.d
    $HOME/.emacs.d/bin/doom install

    # Install personal config for doom
    rm -rf .doom.d 2> /dev/null || true # remove doom config dir if already exists
    git clone git@github.com:ggbaker/doom-emacs-config ~/.doom.d
    $HOME/.emacs.d/bin/doom sync

    # return to script directory
    cd $SCRIPTDIR
fi


###################################################
## Install tex

if [[ "$TEX" == "y" ]]; then
    sudo apt-get install -y texlive-full

    # Install lsp/texlab
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh       # install rust
    cargo install --git https://github.com/latex-lsp/texlab.git --locked
fi


###################################################
## Install fonts

if [[ "$FONTS" == "y" ]]; then
    mkdir -p $HOME/.local/share/fonts
    # Install libertinus fonts
    RELEASES=https://github.com/alerque/libertinus/releases
    # Find most recent release version
    VERSION=$(wget -q -O- $RELEASES | grep -m 1 -oP "(?<=\/v)[0-9.]*?(?=\.zip)") || true
    # for some reason the above line works but, returns error 3 (but only in a script), hence the "|| true"
    # Download and install
    wget -4 -O Libertinus.zip "$RELEASES/download/v$VERSION/Libertinus-$VERSION.zip"
    unzip -qo Libertinus.zip
    cp Libertinus*/static/OTF/* $HOME/.local/share/fonts/
    unset VERSION RELEASES
    rm -rf Libertinus*     # remove zip and unpacked folder

    # Install fonts (for terminal)
    cd $HOME/.local/share/fonts 
    curl -fLo "Droid Sans Mono for Powerline Nerd Font Complete.otf" https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/DroidSansMono/complete/Droid%20Sans%20Mono%20Nerd%20Font%20Complete.otf
    curl -fLo "Hack Regular Nerd Font Complete.ttf" https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Hack/Regular/complete/Hack%20Regular%20Nerd%20Font%20Complete.ttf
    cd $HOME
fi

## return to original directory when done
cd $WORKINGDIR
