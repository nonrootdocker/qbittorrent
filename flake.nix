{
  description = "minimalbase-ng + qbittorrent service";
  inputs = {
    nixpkgs.follows = "minimalbase/nixpkgs";
    minimalbase.url = "github:nonrootdocker/minimalbase-ng";
    qbittorrent-src = {
      url = "github:qbittorrent/qBittorrent";
      flake = false;
    };
  };
  outputs = { self, nixpkgs, minimalbase, qbittorrent-src }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };

    # ----------------------------
    # qBittorrent (headless / nox)
    # ----------------------------
    qbittorrent = pkgs.stdenv.mkDerivation {
      pname = "qbittorrent-nox";
      version = "latest";
      src = qbittorrent-src;
      nativeBuildInputs = with pkgs; [
        cmake
        ninja
        pkg-config
        qt6.qttools
        qt6.wrapQtAppsHook
      ];
      dontWrapQtApps = true;
      buildInputs = with pkgs; [
        boost
        libtorrent-rasterbar-2_0_x
        openssl
        qt6.qtbase
        icu
        zlib
      ];
      cmakeFlags = [
        "-DCMAKE_BUILD_TYPE=Release"
        "-DCMAKE_CXX_STANDARD=20"
        "-DGUI=OFF"
        "-DWEBUI=ON"
        "-DSTACKTRACE=OFF"
      ];
    };
    # ----------------------------
    # User database (/etc/passwd)
    # ----------------------------
    passwdFile = pkgs.writeTextDir "etc/passwd" ''
      root:x:0:0:root:/root:/bin/sh
      qbittorrent:x:1000:1000:qbittorrent:/data:/bin/sh
    '';

    # ----------------------------
    # ABI descriptor for container-init
    # ----------------------------
    qbittorrentAbi = pkgs.writeTextFile {
      name = "qbittorrent-abi.json";
      text = builtins.toJSON {
        version = 2;
        process = {
          exec = "${qbittorrent}/bin/qbittorrent-nox";
          args = [ "--profile=/data" ];
        };
      };
      destination = "/app/main";
    };

  in {
    packages.${system} = {
      default = self.packages.${system}.qbittorrent-image;
      qbittorrent-image = pkgs.dockerTools.buildImage {
        name = "minimalbase-qbittorrent";
        tag = "latest";
        fromImage = minimalbase.packages.${system}.base-image;
        copyToRoot = pkgs.buildEnv {
          name = "root";
          paths = [
            pkgs.coreutils
            pkgs.tzdata
            pkgs.cacert
            pkgs.openssl
            pkgs.qt6.qtbase
            pkgs.libtorrent-rasterbar-2_0_x
            qbittorrent
            qbittorrentAbi
            passwdFile
          ];
        };
        config = {
          Entrypoint = [ "${minimalbase.packages.${system}.container-init}/bin/container-init" ];
          User = "1000:1000";
          Env = [
            "PATH=/bin"
            "TZ=UTC"
            "LANG=en_US.UTF-8"
          ];
        };
      };
    };
  };
}
