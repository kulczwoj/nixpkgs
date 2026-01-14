{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  cudaPackages,
  config,
  cudaSupport ? config.cudaSupport,
}:

let
  variant = if cudaSupport then "gpu" else "cpu";
  variants = {
    cpu = {
      hash = "sha256-tpJ5XzrRmMUxsCrrK8gUZWjSSq9qXb9fqkOQfEAo/XM=";
      buildInputs = [
        (lib.getLib stdenv.cc.cc)
      ];
    };
    gpu = {
      hash = "sha256-9k7DA53E/hh9zzMhX0D6BZOZWwOoiNEi/tdYHONIFeU=";
      buildInputs = (
        with cudaPackages;
        [
          cudatoolkit
          cudnn
        ]
      );
    };
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "libtensorflow-${variant}";
  version = "2.18.1";

  src = fetchurl {
    url = "https://storage.googleapis.com/tensorflow/versions/${finalAttrs.version}/${finalAttrs.pname}-linux-x86_64.tar.gz";
    inherit (variants.${variant}) hash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  inherit (variants.${variant}) buildInputs;

  sourceRoot = ".";

  # Unpack tarball to subdir, preventing copying `env-vars` to $out in `installPhase`
  preUnpack = ''
    mkdir source
    cd source
  '';

  dontPatch = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -pr --reflink=auto -- . $out

    runHook postInstall
  '';

  meta = {
    description = "Computation using data flow graphs for scalable machine learning";
    longDescription = ''
      Standalone binary distribution of TensorFlow libraries.

      Standalone distributions ship `libtensorflow.so` with embedded `VERS_1.0`
      string, which is required be some tools relying on `libtensorflow`, for
      example popular RC Astro plugins for PixInsight.

      PyPi binary distributions of TensorFlow used in `tensorflow-bin` ship
      `libtensorflow_cc.so` without embedded `VERS_1.0` string.

      Publishing standalone `libtensorflow` packages was dropped in TensorFlow 2.19.0.
    '';
    homepage = "http://tensorflow.org";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ kulczwoj ];
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
