# $OpenBSD: dot.profile,v 1.8 2022/08/10 07:40:37 tb Exp $
#
# sh/ksh initialization

PATH=$HOME/build/build-rust/install_dir/nightly/bin:$HOME/.cargo/bin:$HOME/.bin:$HOME/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/X11R6/bin:/usr/local/bin:/usr/local/sbin
export PATH HOME TERM

export LIBCLANG_PATH=/usr/local/llvm21/lib

export LD_LIBRARY_PATH=$HOME/build/build-rust/install_dir/nightly/lib:$LD_LIBRARY_PATH

export ENV=$HOME/.kshrc
