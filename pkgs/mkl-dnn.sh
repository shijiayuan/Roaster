# ================================================================
# Compile Intel MKL-DNN
# ================================================================

[ -e $STAGE/mkl-dnn ] && ( set -xe
    cd $SCRATCH

    . "$ROOT_DIR/pkgs/utils/git/version.sh" oneapi-src/oneDNN,v
    # until git clone --depth 1 -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    until git clone -b "$GIT_TAG" "$GIT_REPO" mkl-dnn; do echo 'Retrying'; done
    cd mkl-dnn
    
    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel')
            set +xe
            . scl_source enable devtoolset-8
            set -xe
            export CC="gcc" CXX="g++"
            ;;
        'ubuntu')
            export CC="gcc-8" CXX="g++-8"
            ;;
        esac

        set +xe
        . "/opt/intel/compilers_and_libraries/$(uname -s | tr '[A-Z]' '[a-z]')/bin/compilervars.sh" intel64
        . /opt/intel/mkl/bin/mklvars.sh intel64
        set -xe

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"

        mkdir -p build
        cd $_

        export MKLDNN_VERBOSE=1

        cmake                                       \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C_COMPILER="$CC"                \
            -DCMAKE_CXX_COMPILER="$CXX"             \
            -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
            -D{DNNL,MKLDNN}_CPU_RUNTIME=OMP         \
            -D{DNNL,MKLDNN}_LIBRARY_TYPE=SHARED     \
            -D{{DNNL,MKLDNN}_,}ARCH_OPT_FLAGS"$(    \
                $TOOLCHAIN_CPU_NATIVE               \
                && echo "_PLACE_HOLDER="            \
                || echo "='-march=haswell -mtune=generic'"  \
            )"                                      \
            -G"Ninja"                               \
            ..

        time cmake --build .
        CTEST_PARALLEL_LEVEL="$(nproc)" time cmake --build . --target test
        time cmake --build . --target install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/mkl-dnn
)
sudo rm -vf $STAGE/mkl-dnn
sync || true
