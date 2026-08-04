#!/usr/bin/env bash

HOME_EMAIL="ti@daleggetts.com"
HOME_SSHKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHMOKogNrOncCCAKczMINsi5rKoOOEEqLB+9bcNpzuDf"
WORK_EMAIL="tileggett@google.com"
WORK_SSHKEY="key::ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBPBZJcRJEqcyZ6AvB18FkqcRldx6rK4Ty2G73rbntrficMf9UKWPSaBDupmW6tauRE3lpmlvJHGowg0L09xehwY= tileggett@gnubby.key"

SPACK_VERSION="1.2.2"

ALLOWED_GCP_SA_HASHES=(
    "74c2432577bbc644b93f21e9b502ee9795a248a69b6e3f97b3468ad2209b9c86"
)

PROFILE="home"
EMAIL=${HOME_EMAIL}
SSHKEY=${HOME_SSHKEY}

SLURM="no"
PRIVILEGED="no"
while getopts "psw" opt; do
    case ${opt} in
        w)
            PROFILE="work"
            EMAIL=${WORK_EMAIL}
            SSHKEY=${WORK_SSHKEY}
            ;;
        s)
            SLURM="yes"
            ;;
        p)
            PRIVILEGED="yes"
            ;;
    esac
done

# Get installed Git version
# Git configuration
REQUIRED_MAJOR=2
REQUIRED_MINOR=34

# Get installed Git version
# Git signing was first introduced in v2.34
INSTALLED_VERSION=$(git --version | awk '{print $3}')
INSTALLED_MAJOR=$(echo "$INSTALLED_VERSION" | cut -d. -f1)
INSTALLED_MINOR=$(echo "$INSTALLED_VERSION" | cut -d. -f2)

# Check if ssh-keygen supports the -Y flag required for SSH commit signing
SSH_SIGNING_SUPPORTED="no"
if command -v ssh-keygen >/dev/null 2>&1; then
    # ssh-keygen outputs its usage to stderr when given an unknown flag or empty -Y
    if ssh-keygen -Y sign 2>&1 | grep -q "unknown option"; then
        SSH_SIGNING_SUPPORTED="no"
    else
        SSH_SIGNING_SUPPORTED="yes"
    fi
fi

# Compare versions and enforce base configurations
[ "$(git config --global --get user.name)" != "Ti Leggett" ] && git config --global user.name "Ti Leggett"
[ "$(git config --global --get pull.rebase)" != "false" ] && git config --global pull.rebase "false"
[ "$(git config --global --get user.email)" != "${EMAIL}" ] && git config --global user.email "${EMAIL}"
if ! $( grep -q ".vscode/" ~/.gitignore_global ); then
    echo ".vscode/" >> "${HOME}/.gitignore_global"
    [ "$(git config --global --get core.excludefiles)" != "${HOME}/.gitignore_global" ] && git config --global core.excludesfile "${HOME}/.gitignore_global"
fi

# Determine if we can safely enable SSH commit signing
GIT_VERSION_VALID=0
if (( INSTALLED_MAJOR > REQUIRED_MAJOR )) || (( INSTALLED_MAJOR == REQUIRED_MAJOR && INSTALLED_MINOR >= REQUIRED_MINOR )); then
    GIT_VERSION_VALID=1
fi

if [ ${GIT_VERSION_VALID} -eq 1 ] && [ "${SSH_SIGNING_SUPPORTED}" = "yes" ]; then
    # Enable signing
    [ "$(git config --global --get user.signingkey)" != "${SSHKEY}" ] && git config --global user.signingkey "${SSHKEY}"
    [ "$(git config --global --get gpg.format)" != "ssh" ] && git config --global gpg.format "ssh"
    [ "$(git config --global --get commit.gpgsign)" != "true" ] && git config --global commit.gpgsign "true"
    [ "$(uname -s)" = "Darwin" -a -x "/Applications/1Password.app/Contents/MacOS/op-ssh-sign" -a "$(git config --global --get gpg.ssh.program)" != "/Applications/1Password.app/Contents/MacOS/op-ssh-sign" ] && git config --global gpg.ssh.program "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
else
    # Explicitly disable signing and clean up settings if not supported on this platform
    echo "SSH commit signing is not supported on this platform (Missing Git 2.34+ or OpenSSH 8.2+). Disabling signing."
    [ "$(git config --global --get commit.gpgsign)" = "true" ] && git config --global commit.gpgsign "false"
    git config --global --unset user.signingkey 2>/dev/null
    git config --global --unset gpg.format 2>/dev/null
    git config --global --unset gpg.ssh.program 2>/dev/null
fi

# Install Homebrew (macOS)
if [ `uname -s` = "Darwin" ]; then
    if $( ! `which brew > /dev/null 2>&1` ); then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
fi

# Install Terminal Defaults (macOS)
if [ `uname -s` = "Darwin" ]; then
    if [ "`defaults read com.apple.Terminal "Default Window Settings"`" != "Github Dark" ]; then
        open "Github Dark.terminal"
        defaults write com.apple.Terminal "Default Window Settings" -string "Github Dark"
        defaults write com.apple.Terminal "Startup Window Settings" -string "Github Dark"
        defaults write com.apple.Terminal CopyAttributesProfile com.apple.Terminal.no-attributes
    fi
fi

if ((BASH_VERSINFO <= 4 )); then
    echo "Current running bash version is not greater than 4."
    if [ `uname -s` = "Darwin" ]; then
        echo "Installing newer bash via Homebrew."
        echo "After installation, edit Terminal settings to use newly isntalled bash."
        brew install bash bash-completion@2
    fi
fi

PYUSERBASE=`python3 -c "import site; print(site.USER_BASE)"`
PYLOCAL=${HOME}/.local
if [ ! -e ${PYLOCAL} ]; then
    if [ `uname -s` = "Darwin" ]; then
        [ ! -d ${PYUSERBASE} ] && install -d ${PYUSERBASE}
        ln -sf ${PYUSERBASE} ${PYLOCAL}
    else
        install -d ${PYLOCAL}
        install -d ${PYLOCAL}/bin
        install -d ${PYLOCAL}/share
    fi
fi
install -d ${PYLOCAL}/tmp

PIP_VERSION=$(python3 -m pip --version | awk '{print $2}')
PIP_MAJOR=$(echo "${PIP_VERSION}" | cut -d. -f1)
PIP_MINOR=$(echo "${PIP_VERSION}" | cut -d. -f2)
if (( PIP_MAJOR >= 23 && PIP_MINOR >= 1 )); then
   PIP_OPTIONS="--user --break-system-packages"
elif [ ${PROFILE} = "work" -a  ${PRIVILEGED} = "yes" ]; then
   PIP_OPTIONS="--user --break-system-packages"
else 
   PIP_OPTIONS="--user"
fi

# Install flake8
if $( ! `which flake8 > /dev/null 2>&1` ); then
    if [ `uname -s` = "Darwin" ]; then
        brew install flake8
    else
        python3 -m pip install ${PIP_OPTIONS} flake8
    fi
fi


# Install Pygments
if $( ! `which pygmentize > /dev/null 2>&1` ); then
    if [ `uname -s` = "Darwin" ]; then
        brew install pygments
    else
        python3 -m pip install ${PIP_OPTIONS} Pygments
    fi
fi

# Install Pandoc
if $( ! `which pandoc > /dev/null 2>&1` ); then
    if [ `uname -s` = "Darwin" ]; then
        brew install groff pandoc
    else
        case `uname -m` in
            "x86_64")
                PANDOC_ARCH="amd64"
                ;;
            "aarch64")
                PANDOC_ARCH="arm64"
                ;;
            *)
                PANDOC_ARCH="unknown"
                ;;
        esac
        if [ ${PANDOC_ARCH} != "unknown" ]; then
            PANDOC_VER="3.1.8"
            pushd ${PYLOCAL}/tmp
            [ -f ${PYLOCAL}/tmp/pandoc-${PANDOC_VER}-linux-${PANDOC_ARCH}.tar.gz ] && rm -f ${PYLOCAL}/tmp/pandoc-${PANDOC_VER}-linux-${PANDOC_ARCH}.tar.gz
            curl -s -S -L -O https://github.com/jgm/pandoc/releases/download/${PANDOC_VER}/pandoc-${PANDOC_VER}-linux-${PANDOC_ARCH}.tar.gz
            tar zxf pandoc-${PANDOC_VER}-linux-${PANDOC_ARCH}.tar.gz -C ${PYLOCAL}
            rm -f pandoc-${PANDOC_VER}-linux-${PANDOC_ARCH}.tar.gz
            popd

            if [ -L ${PYLOCAL}/pandoc ]; then
                unlink ${PYLOCAL}/pandoc
                ln -sf ${PYLOCAL}/pandoc-${PANDOC_VER} ${PYLOCAL}/pandoc
            elif [ -d ${PYLOCAL}/pandoc ]; then
                echo "!!!!! ${PYLOCAL}/pandoc exists. Moving out of the way. !!!!!"
                mv ${PYLOCAL}/pandoc ${PYLOCAL}/pandoc.old
                ln -sf ${PYLOCAL}/pandoc-${PANDOC_VER} ${PYLOCAL}/pandoc
            elif [ -e ${PYLOCAL}/pandoc ]; then
                echo "!!!!! ${PYLOCAL}/pandoc exists. Unsure what to do. !!!!!"
            elif [ ! -e ${PYLOCAL}/pandoc ]; then
                ln -sf ${PYLOCAL}/pandoc-${PANDOC_VER} ${PYLOCAL}/pandoc
            fi
            [ ! -L ${PYLOCAL}/bin/pandoc ] && ln -sf ${PYLOCAL}/pandoc/bin/pandoc ${PYLOCAL}/bin/pandoc
            [ ! -d ${PYLOCAL}/share/man -o ! -d ${PYLOCAL}/share/man/man1 ] && install -d ${PYLOCAL}/share/man/man1
            [ ! -L ${PYLOCAL}/share/man/man1/pandoc.1.gz ] && ln -sf ${PYLOCAL}/pandoc/share/man/man1/pandoc.1.gz ${PYLOCAL}/share/man/man1/pandoc.1.gz
        else
            echo "There isn't a prebuilt pandoc binary for this architecture. Install pandoc manually."
        fi
    fi
fi

# Install Bash-it
if [ ! -d ${HOME}/.bash_it ]; then
    git clone --depth=1 https://github.com/Bash-it/bash-it.git ~/.bash_it
    ${HOME}/.bash_it/install.sh --silent --no-modify-config
    source ${HOME}/.bash_it/bash_it.sh
    bash-it enable plugin base git man ssh
    [ `uname -s` = "Darwin" ] && bash-it enable plugin osx
    [ ${PROFILE} = "work" ] && bash-it enable plugin tmux
    bash-it enable alias general git vim
    [ `uname -s` = "Darwin" ] && bash-it enable alias homebrew osx
    [ `uname -s` = "Linux" ] && bash-it enable alias systemd
    #[ ${PROFILE} = "work" ] && bash-it enable alias vault
    [ ${PROFILE} = "work" ] && bash-it enable alias tmux
    bash-it enable completion git pip pip3 pipx ssh
    [ `uname -s` = "Darwin" ] && bash-it enable completion brew
    #[ ${PROFILE} = "work" ] && bash-it enable completion vault
    bash-it enable completion tmux
    if $( `which gcloud > /dev/null 2>&1` ); then
        bash-it enable completion gcloud
    fi
    bash-it reload
fi

# Configure Vim
# Make sure all the necessary directories exist
for dir in autoload bundle ftdetect ftplugin indent syntax; do
    install -d -o ${USER} -m 0755 ${HOME}/.vim/${dir}
done

# Download all the Vim bundles
pushd ${HOME}/.vim/bundle
declare -A repos
repos[Vundle.vim]="https://github.com/VundleVim/Vundle.vim.git"
repos[vim-bundler]="https://github.com/tpope/vim-bundler.git"
repos[vim-flake8]="https://github.com/nvie/vim-flake8.git"
repos[vim-pathogen]="https://github.com/tpope/vim-pathogen.git"
repos[vim-projectionist]="https://github.com/tpope/vim-projectionist.git"
repos[vim-python-pep8-indent]="https://github.com/Vimjas/vim-python-pep8-indent.git"
repos[vim-rails]="https://github.com/tpope/vim-rails.git"
repos[vim-rake]="https://github.com/tpope/vim-rake.git"
repos[vim-plug]="https://github.com/junegunn/vim-plug.git"

for repo in ${!repos[@]}; do
    if [ -d ${repo} ]; then
        pushd ${repo}
        git pull
        popd
    else
        git clone ${repos[${repo}]}
    fi
done
popd

# If the Plug isn't set to autoload, make it so
[ ! -e ${HOME}/.vim/autoload/plug.vim ] && ln -sf ${HOME}/.vim/bundle/vim-plug/plug.vim ${HOME}/.vim/autoload/plug.vim

echo "Checking for differences of ${HOME}/.vimrc..."
diff -u vimrc ${HOME}/.vimrc
rc=$?
if [ ${rc} -ne 0 ]; then
    echo "Installing new ${HOME}/.vimrc. Refer to above for differences."
    [ -f ${HOME}/.vimrc ] && cp ${HOME}/.vimrc ${HOME}/.vimcrc.bak
    install -o ${USER} -m 0644 vimrc ${HOME}/.vimrc
    vim +PlugInstall +qall
fi

# Instal rc files
echo "Checking for differences of ${HOME}/.bashrc..."
diff -u bashrc ${HOME}/.bashrc
rc=$?
if [ ${rc} -ne 0 ]; then
    echo "Installing new ${HOME}/.bashrc. Refer to above for differences."
    [ -f ${HOME}/.bashrc ] && cp ${HOME}/.bashrc ${HOME}/.bashrc.bak
    install -o ${USER} -m 0644 bashrc ${HOME}/.bashrc
fi

echo "Checking for differences of ${HOME}/.bash_profile..."
diff -u bash_profile ${HOME}/.bash_profile
rc=$?
if [ ${rc} -ne 0 ]; then
    echo "Installing new ${HOME}/.bash_profile. Refer to above for differences."
    [ -f ${HOME}/.bash_profile ] && cp ${HOME}/.bash_profile ${HOME}/.bash_profile.bak
    install -o ${USER} -m 0644 bash_profile ${HOME}/.bash_profile
fi

echo "Checking for differences of ${HOME}/.lessfilter..."
diff -u lessfilter ${HOME}/.lessfilter
rc=$?
if [ ${rc} -ne 0 ]; then
    echo "Installing new ${HOME}/.lessfilter. Refer to above for differences."
    [ -f ${HOME}/.lessfilter ] && cp ${HOME}/.lessfilter ${HOME}/.lessfilter.bak
    install -o ${USER} -m 0755 lessfilter ${HOME}/.lessfilter
fi

echo "Checking for differences of ${HOME}/.screenrc..."
diff -u screenrc ${HOME}/.screenrc
rc=$?
if [ ${rc} -ne 0 ]; then
    echo "Installing new ${HOME}/.screenrc. Refer to above for differences."
    [ -f ${HOME}/.screenrc ] && cp ${HOME}/.screenrc ${HOME}/.screenrc.bak
    install -o ${USER} -m 0644 screenrc ${HOME}/.screenrc
fi

echo "Checking for differences of ${HOME}/.tmux.conf..."
diff -u tmux.conf ${HOME}/.tmux.conf
rc=$?
if [ ${rc} -ne 0 ]; then
    echo "Installing new ${HOME}/.tmux.conf. Refer to above for differences."
    [ -f ${HOME}/.tmux.conf ] && cp ${HOME}/.tmux.conf ${HOME}/.tmux.conf.bak
    install -o ${USER} -m 0644 tmux.conf ${HOME}/.tmux.conf
fi

# Install XQuartz
if [ `uname -s` = "Darwin" ]; then
    if $( ! `which xauth > /dev/null 2>&1` ); then
        echo "XQuartz not found. Installing XQuartz..."
        brew install xquartz
        if [ `uname -m` == "arm64" ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi
fi
touch ${HOME}/.Xauthority

# Configure SSH
[ ! -d ${HOME}/.ssh ] && install -d -m 0700 ${HOME}/.ssh
[ ! -d ${HOME}/.ssh/.control_channels ] && install -d -m 0700 ${HOME}/.ssh/.control_channels
if ! $( grep -q "${SSHKEY}" ~/.ssh/authorized_keys ); then
    touch ${HOME}/.ssh/authorized_keys && chmod 0600 ${HOME}/.ssh/authorized_keys && echo "${SSHKEY}" >> ${HOME}/.ssh/authorized_keys
fi
if [ ! -f ${HOME}/.ssh/config ]; then
    echo 'ControlPath ~/.ssh/.control_channels/%C' > ${HOME}/.ssh/config
    if $( `which xauth > /dev/null 2>&1` ); then
        echo "XauthLocation `which xauth`" >> ${HOME}/.ssh/config
    fi
    chmod 0600 ${HOME}/.ssh/config
fi

# Slurm Configuration
if [ ${PROFILE} = "work" -a  ${SLURM} = "yes" ]; then
    install -d ${HOME}/.vim/after/syntax/sh
    curl --silent --output ${HOME}/.vim/after/syntax/sh/slurm.vim https://raw.githubusercontent.com/SchedMD/slurm/refs/heads/master/contribs/slurm_completion_help/slurm.vim
    curl --silent --output ${HOME}/.slurm_completion.sh https://raw.githubusercontent.com/SchedMD/slurm/refs/heads/master/contribs/slurm_completion_help/slurm_completion.sh
fi

if [ ${PROFILE} = "work" ]; then
    [ `uname -s` = "Linux" -a ${PRIVILEGED} = "yes" ] && sudo apt install -y git-remote-google google-cloud-cli
    CUSTOM_ALIAS_FILE="${HOME}/.bash_it/aliases/custom.aliases.bash"
    CUSTOM_COMPL_FILE="${HOME}/.bash_it/completion/custom.completion.bash"

    # Python venv
    if [ ! -d ${HOME}/.venv ]; then
        python3 -m venv ${HOME}/.venv
    fi
    source ${HOME}/.venv/bin/activate
    pip install --upgrade pip

    if [ -f /google/bin/releases/jetski-devs/tools/cli ] && { [ ! -f "${CUSTOM_ALIAS_FILE}" ] || ! grep -q "jetski" "${CUSTOM_ALIAS_FILE}"; }; then
        echo 'alias jetski="/google/bin/releases/jetski-devs/tools/cli"' >> ${CUSTOM_ALIAS_FILE}
    fi
    if [ -f /google/bin/releases/gemini-cli/tools/gemini ] && { [ ! -f "${CUSTOM_ALIAS_FILE}" ] || ! grep -q "jetski" "${CUSTOM_ALIAS_FILE}"; }; then
        echo 'alias gemini="/google/bin/releases/gemini-cli/tools/gemini"' >> ${CUSTOM_ALIAS_FILE}
    fi
    if command -v go > /dev/null 2>&1; then
        export PATH=${PATH}:$(go env GOPATH)/bin
    fi
    gerrit_dir="${HOME}/gerrit"
    [ ! -d ${gerrit_dir} ] && install -d ${gerrit_dir}
    pushd ${gerrit_dir}

    if [ ${PRIVILEGED} = "yes" ]; then
        gerrit_url="sso://cloudhpc"
        repo_dir=sup-ssh-utils
        if [ ! -d ${repo_dir} ]; then
            git clone ${gerrit_url}/${repo_dir}
        fi
        pushd ${repo_dir}
        git pull
        export PATH=${gerrit_dir}/${repo_dir}:${PATH}
        ./setup-gcp-ssh-host.bash
        popd
    else
        repo_dir=gcompute-tools
        if [ ! -d ${repo_dir} ]; then
            git clone https://gerrit.googlesource.com/${repo_dir}
        else
            pushd ${repo_dir}
            git pull
            popd
        fi
        systemd_user_path="${HOME}/.config/systemd/user"
        [ ! -d ${systemd_user_path} ] && install -d ${systemd_user_path}
        cat > ${systemd_user_path}/git-cookie-authdaemon.service << EOF
[Unit]
Description=git-cookie-authdaemon required to access git-on-borg from GCE

Wants=network.target
After=syslog.target network-online.target

[Service]
Type=simple
ExecStart=${HOME}/.venv/bin/python3 ${gerrit_dir}/${repo_dir}/git-cookie-authdaemon
Restart=on-failure
RestartSec=10
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
        # TODO: Start the systemd service once that's debugged, for now start it manually
        #systemctl --user daemon-reload
        #systemctl --user enable --now git-cookie-authdaemon
        [ $(pgrep --uid $(id -u) --full --count git-cookie-authdaemon) -eq 0 ] && ${HOME}/.venv/bin/python3 ${gerrit_dir}/${repo_dir}/git-cookie-authdaemon
        [ "$(git config --global --get http.cookiefile)" != "${HOME}/.git-credential-cache/cookie" ] && git config --global http.cookiefile ${HOME}/.git-credential-cache/cookie
        gerrit_url="https://cloudhpc.googlesource.com"
    fi
    current_sa=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email)
    current_sa_hash=$(echo -n "${current_sa}" | sha256sum | awk '{print $1}')
    sa_authorized=false
    for hash in "${ALLOWED_SA_HASHES[0]}"; do 
        [ "${current_sa_hash}" = "${hash}" ] && (sa_authorized=true; break)
    done
    if [ ${sa_authorized} = true ]; then
        repo_dir=hpc-toolkit-blueprints
        if [ ! -d ${repo_dir} ]; then
            git clone ${gerrit_url}/${repo_dir} && (
                pushd ${repo_dir} && f=`git rev-parse --git-dir`/hooks/commit-msg
                mkdir -p $(dirname $f)
                curl -Lo $f https://gerrit-review.googlesource.com/tools/hooks/commit-msg
                chmod +x $f
                popd
            )
        else
            pushd ${repo_dir}
            git pull
            popd
        fi
        repo_dir=spack-packages
        if [ ! -d ${repo_dir} ]; then
            git clone ${gerrit_url}/${repo_dir} && (
                pushd ${repo_dir} && f=`git rev-parse --git-dir`/hooks/commit-msg
                mkdir -p $(dirname $f)
                curl -Lo $f https://gerrit-review.googlesource.com/tools/hooks/commit-msg
                chmod +x $f
                popd
            )
        else
            pushd ${repo_dir}
            git pull
            popd
        fi
        repo_dir=ramble-applications
        if [ ! -d ${repo_dir} ]; then
            git clone ${gerrit_url}/${repo_dir} && (
                pushd ${repo_dir} && f=`git rev-parse --git-dir`/hooks/commit-msg
                mkdir -p $(dirname $f)
                curl -Lo $f https://gerrit-review.googlesource.com/tools/hooks/commit-msg
                chmod +x $f
                popd
            )
        else
            pushd ${repo_dir}
            git pull
            popd
        fi
    fi
    popd

    git_dir="${HOME}/git"
    [ ! -d ${git_dir} ] && install -d ${git_dir}
    pushd ${git_dir}
    # Cluster Toolkit Contiguration
    repo_dir=cluster-toolkit
    if [ ! -d ${repo_dir} ]; then
        git clone git@github.com:GoogleCloudPlatform/${repo_dir}.git
    fi
    pushd ${repo_dir}
    git pull
    make
    popd
    export PATH=${PATH}:${git_dir}/${repo_dir}
    if command -v ghpc >/dev/null 2>&1 && { [ ! -f "${CUSTOM_COMPL_FILE}" ] || ! grep -q "gcluster" "${CUSTOM_COMPL_FILE}"; }; then
        ghpc completion bash >> ${HOME}/.bash_it/completion/custom.completion.bash
    fi
    repo_dir=spack
    if [ ! -d ${repo_dir} ]; then
        git clone --depth=2 https://github.com/spack/${repo_dir}.git
    else
        pushd ${repo_dir}
        git pull
        git fetch --tags
        git checkout tags/v${SPACK_VERSION}
        popd
    fi
    [ -f ${git_dir}/spack/share/spack/setup-env.sh ] && source ${git_dir}/spack/share/spack/setup-env.sh
    repo_dir=spack-packages
    if [ ! -d ${repo_dir} ]; then
        git clone --depth=2 git@github.com:tteggelit/${repo_dir}.git
    else
        pushd ${repo_dir}
        git pull
        git remote add upstream https://github.com/spack/${repo_dir}.git
        git fetch upstream
        popd
    fi
    if ! $( spack repo list | grep -q "${gerrit_dir}/spack-packages" ); then
        spack repo add "${gerrit_dir}/spack-packages"
    fi
    repo_dir=ramble
    if [ ! -d ${repo_dir} ]; then
        git clone -c feature.manyfiles=true git@github.com:tteggelit/${repo_dir}.git
    else
        pushd ${repo_dir}
        git pull
        git remote add upstream https://github.com/GoogleCloudPlatform/${repo_dir}.git
        git fetch upstream
        popd
    fi
    [ -f ${git_dir}/ramble/share/ramble/setup-env.sh ] && source ${git_dir}/ramble/share/ramble/setup-env.sh
    if [ ! -f "${CUSTOM_ALIAS_FILE}" ] || ! grep -q "prw" "${CUSTOM_ALIAS_FILE}"; then
        echo 'alias prw="pushd ${RAMBLE_WORKSPACE}"' >> ${CUSTOM_ALIAS_FILE}
    fi
    if [ ! -f "${CUSTOM_ALIAS_FILE}" ] || ! grep -q "ro" "${CUSTOM_ALIAS_FILE}"; then
        echo 'alias ro="ramble on"' >> ${CUSTOM_ALIAS_FILE}
    fi
    if [ ! -f "${CUSTOM_ALIAS_FILE}" ] || ! grep -q "rwa" "${CUSTOM_ALIAS_FILE}"; then
        echo 'alias rwa="ramble workspace activate"' >> ${CUSTOM_ALIAS_FILE}
    fi
    if [ ! -f "${CUSTOM_ALIAS_FILE}" ] || ! grep -q "rwan" "${CUSTOM_ALIAS_FILE}"; then
        echo 'alias rwan="ramble workspace analyze"' >> ${CUSTOM_ALIAS_FILE}
    fi
    if [ ! -f "${CUSTOM_ALIAS_FILE}" ] || ! grep -q "rwc" "${CUSTOM_ALIAS_FILE}"; then
        echo 'alias rwc="ramble workspace create"' >> ${CUSTOM_ALIAS_FILE}
    fi
    if [ ! -f "${CUSTOM_ALIAS_FILE}" ] || ! grep -q "rwd" "${CUSTOM_ALIAS_FILE}"; then
        echo 'alias rwd="ramble workspace deactivate"' >> ${CUSTOM_ALIAS_FILE}
    fi
    if [ ! -f "${CUSTOM_ALIAS_FILE}" ] || ! grep -q "rwe" "${CUSTOM_ALIAS_FILE}"; then
        echo 'alias rwe="ramble workspace edit"' >> ${CUSTOM_ALIAS_FILE}
    fi
    if [ ! -f "${CUSTOM_ALIAS_FILE}" ] || ! grep -q "rwi" "${CUSTOM_ALIAS_FILE}"; then
        echo 'alias rwi="ramble workspace info"' >> ${CUSTOM_ALIAS_FILE}
    fi
    if [ ! -f "${CUSTOM_ALIAS_FILE}" ] || ! grep -q "rwls" "${CUSTOM_ALIAS_FILE}"; then
        echo 'alias rwls="ramble workspace list"' >> ${CUSTOM_ALIAS_FILE}
    fi
    if [ ! -f "${CUSTOM_ALIAS_FILE}" ] || ! grep -q "rwrm" "${CUSTOM_ALIAS_FILE}"; then
        echo 'alias rwrm="ramble workspace remove"' >> ${CUSTOM_ALIAS_FILE}
    fi
    if [ ! -f "${CUSTOM_ALIAS_FILE}" ] || ! grep -q "rws" "${CUSTOM_ALIAS_FILE}"; then
        echo 'alias rws="ramble workspace setup"' >> ${CUSTOM_ALIAS_FILE}
    fi
    popd
    pip install -r ${git_dir}/ramble/requirements.txt
    pip install -r ${git_dir}/ramble/requirements-dev.txt
    if [ ! -x ${git_dir}/ramble/.git/hooks/pre-commit ]; then
        pushd ${git_dir}/ramble
        pre-commit install
    fi
    if [ ${sa_authorized} = true ]; then
        if ! $( ramble repo list | grep -q "${gerrit_dir}/ramble-applications" ); then
            ramble repo add "${gerrit_dir}/ramble-applications"
        fi
        if ! $( spack repo list | grep -q "${gerrit_dir}/spack-packages" ); then
            spack repo add "${gerrit_dir}/spack-packages"
        fi
    fi
fi

[ -d ${PYLOCAL}/tmp ] && rm -rf ${PYLOCAL}/tmp
