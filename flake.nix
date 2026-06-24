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

          version = "0.1.0";
          bundleId = "com.thattomperson.MuteKey";
        in rec {
          swiftpm2nix = swiftixPkgs.swiftpm2nix;
          default = mkSwiftPackage {
            pname = "mutekey";
            inherit version;
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
              ks=.build/checkouts/KeyboardShortcuts/Sources/KeyboardShortcuts

              # Strip three `#Preview` blocks from Recorder.swift — the #Preview
              # macro needs Xcode's closed-source PreviewsMacros plugin, which the
              # swiftix (swift.org) toolchain can't expand, so the build fails.
              f="$ks/Recorder.swift"
              awk '/^#Preview \{/{skip=1; next} skip && /^\}/{skip=0; next} !skip{print}' "$f" > "$f.tmp"
              mv "$f.tmp" "$f"

              # Redirect KeyboardShortcuts' only Bundle.module use (a localized
              # string lookup in Utilities.swift) to a resilient bundle that
              # checks Contents/Resources first. SwiftPM's generated Bundle.module
              # accessor hardcodes the .app ROOT and fatalErrors if absent — which
              # forces a root-level resource bundle that breaks codesign. Patching
              # the generated accessor doesn't stick (SwiftPM regenerates it each
              # build), so patch this real source file instead. The custom lookup
              # never fatalErrors: worst case it falls back to .main and
              # NSLocalizedString returns the key (English).
              u="$ks/Utilities.swift"
              sed -i.bak 's|bundle: \.module|bundle: keyboardShortcutsBundle|' "$u"
              rm -f "$u.bak"
              cat >> "$u" <<'SWIFT'

              // Injected by MuteKey's flake: locate the resource bundle without
              // the fatalError-on-miss behavior of the generated Bundle.module.
              let keyboardShortcutsBundle: Bundle = {
                  let name = "KeyboardShortcuts_KeyboardShortcuts.bundle"
                  let candidates = [
                      Bundle.main.resourceURL,           // .app Contents/Resources
                      Bundle.main.bundleURL,             // next to a plain binary
                  ].compactMap { $0?.appendingPathComponent(name) }
                  for url in candidates {
                      if let bundle = Bundle(path: url.path) { return bundle }
                  }
                  return .main
              }()
              SWIFT
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

          # Assemble a macOS .app bundle from the plain executable + resources.
          #
          # Everything lives under the standard Contents/Resources so the bundle
          # root stays clean and `codesign` is happy:
          #  - Our sounds → Contents/Resources, loaded via Bundle.main.
          #  - KeyboardShortcuts' resource bundle → Contents/Resources too; its
          #    accessor was patched in preBuild to look in Bundle.main.resourceURL
          #    rather than the .app root.
          # LSUIElement=true keeps it a menu-bar-only (accessory) app.
          app = pkgs.runCommand "MuteKey.app" { } ''
            app=$out/Applications/MuteKey.app
            mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

            cp ${default}/bin/MuteKey "$app/Contents/MacOS/MuteKey"
            chmod +w "$app/Contents/MacOS/MuteKey"

            # Our bundled sounds → Contents/Resources (Bundle.main location).
            if [ -d "${default}/bin/MuteKey_MuteKey.bundle" ]; then
              cp ${default}/bin/MuteKey_MuteKey.bundle/*.wav "$app/Contents/Resources/"
            fi

            # Dependency resource bundles → Contents/Resources (patched path).
            for b in ${default}/bin/KeyboardShortcuts_*.bundle; do
              [ -e "$b" ] && cp -R "$b" "$app/Contents/Resources/$(basename "$b")"
            done

            # App icon (committed; regenerate with Tools/generate-icon.sh).
            cp ${./Sources/Resources/AppIcon.icns} "$app/Contents/Resources/AppIcon.icns"

            cat > "$app/Contents/Info.plist" <<PLIST
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0"><dict>
              <key>CFBundleExecutable</key><string>MuteKey</string>
              <key>CFBundleIdentifier</key><string>${bundleId}</string>
              <key>CFBundleName</key><string>MuteKey</string>
              <key>CFBundleDisplayName</key><string>MuteKey</string>
              <key>CFBundleShortVersionString</key><string>${version}</string>
              <key>CFBundleVersion</key><string>${version}</string>
              <key>CFBundlePackageType</key><string>APPL</string>
              <key>CFBundleIconFile</key><string>AppIcon</string>
              <key>LSMinimumSystemVersion</key><string>26.0</string>
              <key>LSUIElement</key><true/>
            </dict></plist>
            PLIST

            # Note: the .app is left UNSIGNED. Codesigning needs Apple's
            # codesign_allocate, which isn't available in the nix sandbox, so sign
            # outside the build after copying it out of the store, e.g.:
            #   cp -R result/Applications/MuteKey.app /Applications/
            #   chmod -R u+w /Applications/MuteKey.app
            #   codesign --force --deep --sign - /Applications/MuteKey.app
            # Ad-hoc signing is enough to run locally. (codesign --verify will
            # warn about the root-level KeyboardShortcuts bundle — see layout note
            # above — which blocks notarization but not local launch.)
          '';
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
