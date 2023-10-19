# Silence stupid zsh default shell warning
export BASH_SILENCE_DEPRECATION_WARNING=1

PATH=${HOME}/bin:${PATH}
MANPATH=${HOME}/share/man:${MANPATH}
LD_LIBRARY_PATH=${HOME}/lib:${LD_LIBRARY_PATH}
export PATH MANPATH LD_LIBRARY_PATH

stty -parenb
