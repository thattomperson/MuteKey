{
  description = "Example Swift project built with swiftix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    swiftix.url = "github:stillwind-ai/swiftix";
  };

  outputs = { self, nixpkgs, swiftix, ... }:
    let
      systems = [ "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems f;
    in {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          swiftixPkgs = swiftix.packages.${system};
          mkSwiftPackage = swiftix.lib.mkSwiftPackage { inherit pkgs; };
          swiftpm2nixHelpers = swiftix.lib.swiftpm2nixHelpers { inherit pkgs; };
        in {
          swiftpm2nix = swiftixPkgs.swiftpm2nix;
          default = mkSwiftPackage {
            pname = "mutekey";
            version = "0.1.0";
            src = ./.;
            swift = swiftix.packages.${system}.swift-6_3;
            swiftpmGenerated = swiftpm2nixHelpers ./nix;
            executableName = "MuteKey";

            buildInputs = [
              pkgs.libiconv
            ];

            appleSdk = pkgs.apple-sdk_26;

            # KeyboardShortcuts' Recorder.swift ends with three `#Preview` blocks
            # for Xcode canvas previews. The `#Preview` macro is backed by the
            # closed-source `PreviewsMacros` plugin that ships only inside Xcode,
            # so the swiftix (open-source swift.org) toolchain can't expand it and
            # the build fails. These previews are dev-only and have no runtime
            # effect, so strip them from the (made-mutable) checkout before build.
            postConfigure = ''
              swiftpmMakeMutable KeyboardShortcuts
              f=.build/checkouts/KeyboardShortcuts/Sources/KeyboardShortcuts/Recorder.swift
              awk '/^#Preview \{/{skip=1; next} skip && /^\}/{skip=0; next} !skip{print}' "$f" > "$f.tmp"
              mv "$f.tmp" "$f"
            '';

            # mkSwiftPackage's installPhase copies only the executable. SwiftPM
            # builds dependency resources (e.g. KeyboardShortcuts' localization
            # bundle) as sibling `*.bundle` directories next to the binary, and
            # `Bundle.module` looks for them there at runtime. Copy them across
            # so the app finds its resources when launched from $out/bin.
            postInstall = ''
              for bundle in .build/release/*.bundle; do
                [ -e "$bundle" ] && cp -r "$bundle" $out/bin/
              done
            '';
          };
        }
      );

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          isDarwin = pkgs.lib.hasSuffix "darwin" system;
          swift = swiftix.packages.${system}.swift-6_3;
        in {
          default = pkgs.mkShell {
            packages = [ swift ]
              ++ pkgs.lib.optionals isDarwin [ pkgs.apple-sdk_26 ]
              ++ pkgs.lib.optionals (!isDarwin) [ pkgs.stdenv.cc ];

            shellHook = pkgs.lib.optionalString isDarwin ''
              export SDKROOT="${pkgs.apple-sdk_26}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
            '' + pkgs.lib.optionalString (!isDarwin) ''
              export C_INCLUDE_PATH="${pkgs.stdenv.cc.libc.dev}/include"
              export LIBRARY_PATH="${pkgs.stdenv.cc.libc}/lib:${pkgs.stdenv.cc.cc.lib}/lib"
            '';
          };
        }
      );
    };
}
