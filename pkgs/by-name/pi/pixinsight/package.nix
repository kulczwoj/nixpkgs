{
  lib,
  callPackage,
  buildFHSEnv,
  cudaPackages,
  libtensorflow-bin,
  config,
  cudaSupport ? config.cudaSupport,
}:

let
  pixinsight = callPackage ./. { };
  inherit (pixinsight) pname version appname;

  # PixInsight ships its own `libtensorflow-cpu`
  libtensorflow-gpu = libtensorflow-bin.override {
    cudaSupport = true;
  };

  targetPkgs =
    pkgs:
    (with pkgs; [
      expat
      glib
      zlib
      udev
      dbus
      nspr
      nss
      openssl

      alsa-lib
      libxkbcommon

      libGL
      libdrm
      qt6Packages.qtbase
      gtk3
      fontconfig
      libjpeg8
      gd

      libssh2
      libpsl
      libidn2

      brotli
      libdeflate

      avahi-compat
      cups
    ])
    ++ (with pkgs.xorg; [
      libX11
      libxcb

      libXcomposite
      libXdamage
      libXext
      libXfixes
      libXinerama
      libXrandr
      libXrender
      libXtst

      libSM
      libICE

      libxkbfile

      xcbutil
      xcbutilimage
      xcbutilkeysyms
      xcbutilrenderutil
      xcbutilwm
      #xcbutilcursor # Bundled by PixInsight
    ])
    ++ lib.optionals cudaSupport (
      with pkgs.cudaPackages;
      [
        cudatoolkit
        cudnn
      ]
    );

  extraInstallCommands = ''
    # Provide second binary matching upstream CLI command (`PixInsight`)
    ln -s $out/bin/{${pname},${appname}}

    # Provide desktop integration files
    ln -s {${pixinsight},$out}/share
  '';

  deployPath = "$HOME/.local/share/${pname}";
  storePathFile = "${deployPath}/opt/${appname}/.store-path";

  # Prepare mutable opt/ for self-update and plugin support
  # Auto-deploy whenever `pixinsight` store path changes
  extraPreBwrapCmds = ''
    read -r DEPLOYED_PATH < "${storePathFile}" 2>/dev/null || DEPLOYED_PATH=""

    if [ "$DEPLOYED_PATH" != "${pixinsight}" ]; then
      echo "${pname}: new ${appname} installation detected"
      echo "${pname}: deploying ${pixinsight}/opt/${appname} to ${deployPath}/opt/${appname}..."

      mkdir -p "${deployPath}"/opt || exit 1
      rm -rf "${deployPath}"/opt/${appname} || exit 1
      cp -R ${pixinsight}/opt/${appname} "${deployPath}"/opt || exit 1
      chmod -R u+w "${deployPath}"/opt/${appname} || exit 1

      echo "${pixinsight}" > "${storePathFile}" || exit 1

      echo "${pname}: deployed successfully"
    fi
  '';

  # Bind-mount mutable opt/ to /opt
  extraBwrapArgs = [
    ''--bind "${deployPath}"/opt /opt''
  ];

  profile = lib.optionalString cudaSupport ''
    export LD_LIBRARY_PATH=${libtensorflow-gpu}/lib
    export XLA_FLAGS=--xla_gpu_cuda_data_dir=${cudaPackages.cudatoolkit}
  '';

  runScript = "/opt/${appname}/bin/${appname}.sh";

  passthru.unwrapped = pixinsight;

  meta = pixinsight.meta // {
    mainProgram = pname;
  };
in
buildFHSEnv {
  inherit
    pname
    version
    targetPkgs
    extraInstallCommands
    extraPreBwrapCmds
    extraBwrapArgs
    profile
    runScript
    passthru
    meta
    ;
}
