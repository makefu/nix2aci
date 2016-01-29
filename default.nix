{ pkgs ? import ((import <nixpkgs> {}).fetchgit {
    url = "https://github.com/NixOS/nixpkgs.git";
    rev = "5e96bac3fb8f12c9c63562938a33595b7553ddbb";
    sha256 = "1qr4xqgc4vnhq1s0xcqp2l6447n8fdp1dh343l6a75fqn2dh6hrk";
    leaveDotGit = true; }) {}
, mkACI ? import lib/mkACI.nix
}:

let 
in {
  acserver = import pkgs/linux/acserver.nix { inherit pkgs mkACI; static=false; };
  bash = import pkgs/linux/bash.nix { inherit pkgs mkACI; static=false; };
  busybox = import pkgs/linux/busybox.nix { inherit pkgs mkACI; static=false; };
  busyboxStatic = import pkgs/linux/busybox.nix { inherit pkgs mkACI; static=true; };
  coreosIpxeServer = import pkgs/linux/coreos-ipxe-server.nix { inherit pkgs mkACI; };
  dnsmasq = import pkgs/linux/dnsmasq.nix { inherit pkgs mkACI; };
  dnsfail = import pkgs/linux/dnsfail.nix { inherit pkgs mkACI; };
  docker = import pkgs/linux/docker.nix { inherit pkgs mkACI; dnsquirks=false; };
  etcd2 = import pkgs/linux/etcd2.nix { inherit pkgs mkACI; };
#  lighthttpd = import pkgs/linux/lighthttpd.nix { inherit pkgs mkACI; };
  pixiecore = import pkgs/linux/pixiecore.nix { inherit pkgs mkACI; static=false; };
  qemu = import pkgs/linux/qemu.nix { inherit pkgs mkACI; };
  rkt = import pkgs/linux/rkt.nix { inherit pkgs mkACI; dnsquirks=false;};
}
