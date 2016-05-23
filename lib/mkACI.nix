args @ { pkgs
, packages
, pkg ? builtins.elemAt packages 0
, acName ? (builtins.parseDrvName pkg.name).name
, acVersion ? if builtins.hasAttr "version" pkg && pkg.version != "" then pkg.version else (builtins.parseDrvName pkg.name).version
, versionAddon ? ""
, arch ? builtins.replaceStrings ["x86_64"] ["amd64"] (builtins.elemAt (pkgs.stdenv.lib.strings.splitString "-" pkg.system) 0)
, os ? builtins.elemAt (pkgs.stdenv.lib.strings.splitString "-" pkg.system) 1
, thin ? false
, acLabels ? {}
, mounts ? {}
, mountsRo ? {}
, ports ? {}
, env ? {}
, exec ? null
, user ? "0"
, group ? "0"
, sign ? true
, isolators ? {}
, dnsquirks ? true
, static ? false
, authors ? null
, homepage ? null
, documentation ? null
, compression ? "gzip"
}:

let
  mkACI = pkgs.goPackages.buildGoPackage rec {
    version = "0.0.1";
    rev = "";
    name = "mkACI-${version}";
    goPackagePath = "github.com/Mic92/nix2aci/lib/mkACI";
    src = ./.;
    buildInputs = [ pkgs.go ];
    extraSrcs = [];
  };
  mountPoint = readOnly: name: {
     "name" = name;
     "path" = mounts.${name};
     "readOnly" = readOnly;
  };
  propertyList = (list:
    builtins.map (l: {"name" = l; "value" = list.${l}; }) (builtins.attrNames list));

  mountPoints = (builtins.map (mountPoint false) (builtins.attrNames mounts));
  mountPointsRo = (builtins.map (mountPoint true) (builtins.attrNames mountsRo));
  name = (builtins.replaceStrings ["go1.5-" "go1.4-" "-"] [ "" "" "_"] acName);
  version = (builtins.replaceStrings ["-"] ["_"] acVersion + versionAddon);
  execArgv = if (builtins.isString exec) then [exec]
    else if (builtins.isList exec) then exec
    else throw "exec should be a list, got: " + (builtins.typeOf exec);

  portProps = (builtins.map (p: {"name" = p;} // ports.${p}) (builtins.attrNames ports));

  optionalAttr = (key: val: if isNull val then {} else {${key} = val; });

  annotations = (optionalAttr "authors" authors) //
                (optionalAttr "homepage" homepage) //
                (optionalAttr "documentation" documentation);

  manifest = {
    acKind = "ImageManifest";
    acVersion = "0.7.4";
    name = name;
    version = version;
    labels = (propertyList (acLabels // {
      os = os;
      arch = arch;
    }));
    app = {
      exec = execArgv;
      user = (toString user);
      group = (toString group);
      mountPoints = mountPoints ++ mountPointsRo;
      ports = portProps;
      isolators = (propertyList isolators);
      environment = (propertyList env);
    };
    annotations = (propertyList annotations);
  };

  bool_to_flag = name: value: if value then "-${name}" else "";

  compressionOptions = {
    none = {
      buildInputs = [];
      compressor = "";
    };
    bzip2 = {
      buildInputs = [pkgs.pbzip2];
      compressor = "pbzip2";
    };
    gzip = {
      buildInputs = [pkgs.pigz];
      compressor = "pigz -nT";
    };
    xz = {
      buildInputs = [pkgs.xz]
      compressor = "xz -T 0 -c -z -"
    }
  };

  execArgv = if (builtins.isString exec) then [exec]
    else if (builtins.isList exec) then exec
    else throw "exec should be a list, got: " + (builtins.typeOf exec);

  compression = if (builtins.hasAttr c)

in
  pkgs.stdenv.mkDerivation rec {
  name = builtins.replaceStrings ["go1.5-" "go1.4-" "-"] [ "" "" "_"] acName;
  version = builtins.replaceStrings ["-"] ["_"] acVersion + versionAddon;

  inherit os;
  inherit arch;

  buildInputs = [ mkACI ];

  # the enclosed environment provides the content for the ACI
  customEnv = pkgs.buildEnv {
    name = name + "-env";
    paths = packages;
  };
  exportReferencesGraph = map (x: [("closure-" + baseNameOf x) x]) packages;

  acname = "${name}-${version}-${os}-${arch}";

  manifestJson = builtins.toFile "manifest" (builtins.toJSON manifest);
  postProcess = builtins.toFile "postprocess.sh" ''
#!/usr/bin/env bash
set -e
out="$( cd "$( dirname "''${BASH_SOURCE[0]}" )" && pwd )"
script_outdir="''${1:-ACIs/}"
echo Linking $out/${acname}.aci into $script_outdir
ln -sf "$out/${acname}.aci" "$script_outdir/"
echo Linking $out/${acname}.mounts into $script_outdir
ln -sf "$out/${acname}.mounts" "$script_outdir"
${if sign then
''gpg2 --yes --batch --armor --output "$script_outdir/${acname}.aci.asc" --detach-sig "$out/${acname}.aci"''
else ""}
'';

  phases = "buildPhase";
  buildPhase = ''
    install -D -m755 "${postProcess}" "$out/postprocess.sh"
    mkACI \
        ${bool_to_flag "thin" thin} \
        ${bool_to_flag "dnsquirks" dnsquirks} \
        ${bool_to_flag "static" static} \
        "${manifestJson}" \
        "${customEnv}" \
        ${if static then (builtins.elemAt packages 0) else "closure-*"} \
        3>&1 4> "$out/metadata.json" 5> "$out/${acname}.mounts" | \
        gzip > "$out/${acname}.aci" \
  '';

}
