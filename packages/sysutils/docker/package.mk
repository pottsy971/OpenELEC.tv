################################################################################
#      This file is part of LibreELEC - http://www.libreelec.tv
#      Copyright (C) 2009-2016 Lukas Rusak (lrusak@libreelec.tv)
#
#  LibreELEC is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 2 of the License, or
#  (at your option) any later version.
#
#  LibreELEC is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with LibreELEC.  If not, see <http://www.gnu.org/licenses/>.
################################################################################

PKG_NAME="docker"
PKG_VERSION="1.11.1"
PKG_REV="1"
PKG_ARCH="any"
PKG_PROJECTS="Generic RPi RPi2"
PKG_LICENSE="ASL"
PKG_SITE="http://www.docker.com/"
PKG_URL="https://github.com/docker/docker/archive/v${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain sqlite go:host containerd runc btrfs-progs"
PKG_PRIORITY="optional"
PKG_SECTION="service/system"
PKG_SHORTDESC="Docker is an open-source engine that automates the deployment of any application as a lightweight, portable, self-sufficient container that will run virtually anywhere."
PKG_LONGDESC="Docker containers can encapsulate any payload, and will run consistently on and between virtually any server. The same container that a developer builds and tests on a laptop will run at scale, in production*, on VMs, bare-metal servers, OpenStack clusters, public instances, or combinations of the above."
PKG_AUTORECONF="no"

PKG_IS_ADDON="no"

unpack() {
  tar -C $BUILD -zxf $SOURCES/$PKG_NAME/v$PKG_VERSION.tar.gz
}

configure_target() {
  export DOCKER_BUILDTAGS="daemon \
                           exclude_graphdriver_devicemapper \
                           exclude_graphdriver_aufs"

  case $TARGET_ARCH in
    x86_64)
      export GOARCH=amd64
      ;;
    arm)
      export GOARCH=arm

      case $TARGET_CPU in
        arm1176jzf-s)
          export GOARM=6
          ;;
        cortex-a7)
         export GOARM=7
         ;;
      esac
      ;;
  esac

  export GOOS=linux
  export CGO_ENABLED=1
  export CGO_NO_EMULATION=1
  export CGO_CFLAGS=$CFLAGS
  export LDFLAGS="-w -linkmode external -extldflags -Wl,--unresolved-symbols=ignore-in-shared-libs -extld $TARGET_CC"
  export GOLANG=$ROOT/$TOOLCHAIN/lib/golang/bin/go
  export GOPATH=$ROOT/$PKG_BUILD/.gopath:$ROOT/$PKG_BUILD/vendor
  export GOROOT=$ROOT/$TOOLCHAIN/lib/golang
  export PATH=$PATH:$GOROOT/bin

  ln -fs $ROOT/$PKG_BUILD $ROOT/$PKG_BUILD/vendor/src/github.com/docker/docker

  # used for docker version
  export GITCOMMIT=$PKG_VERSION
  export VERSION=$PKG_VERSION
  export BUILDTIME="$(date --utc)"
  bash ./hack/make/.go-autogen
}

make_target() {
  mkdir -p bin
  $GOLANG build -v -o bin/docker -a -tags "$DOCKER_BUILDTAGS" -ldflags "$LDFLAGS" ./docker
}

makeinstall_target() {
  mkdir -p $INSTALL/etc
  mkdir -p $INSTALL/usr/sbin
  mkdir -p $INSTALL/usr/config
  mkdir -p $INSTALL/usr/share/services
  ln -sf /storage/.config/docker $INSTALL/etc/docker
  cp bin/docker $INSTALL/usr/sbin
  cp -R $PKG_DIR/config/* $INSTALL/usr/config

  # containerd
  cp -P $(get_build_dir containerd)/bin/containerd $INSTALL/usr/sbin/docker-containerd
  cp -P $(get_build_dir containerd)/bin/containerd-shim $INSTALL/usr/sbin/docker-containerd-shim
  cp -P $(get_build_dir containerd)/bin/ctr $INSTALL/usr/sbin/docker-containerd-ctr

  # runc
  cp -P $(get_build_dir runc)/bin/runc $INSTALL/usr/sbin/docker-runc
}

post_install() {
  enable_service docker.service
}
