# ================================================================
# Compile LMDB
# ================================================================

[ -e $STAGE/lmdb ] && ( set -xe
    cd $SCRATCH

    . "$ROOT_DIR/pkgs/utils/git/version.sh" LMDB/lmdb,LMDB_
    until git clone --depth 1 -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd lmdb

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

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"

        cd libraries/liblmdb

        cat Makefile                                                                                \
        | sed "s/^\(CC[[:space:]]*=[[:space:]]*\).*/\1$(sed 's/\//\\\//g' <<< "$TOOLCHAIN/cc")/"    \
        | sed "s/^\(prefix[[:space:]]*=[[:space:]]*\).*/\1$(sed 's/\//\\\//g' <<< "$INSTALL_ABS")/" \
        | sed 's/\($(SOLIBS)\)/\-Wl,\-soname,$@.$(GIT_TAG_VER) \1/'                                               \
        > .Makefile
        mv -f {.,}Makefile

        git --no-pager diff

        make -j$(nproc)
        make test
        make "$INSTALL_ABS" install -j
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    cd
    rm -rf $SCRATCH/lmdb
)
sudo rm -vf $STAGE/lmdb
sync || true
