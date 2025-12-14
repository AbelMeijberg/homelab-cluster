{
  description = "Homelab cluster development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Core k8s tools
            kubectl
            kubeseal
            kustomize

            # Selected extras
            helm
            k9s
            yq-go
            jq
          ];

          shellHook = ''
            echo "Homelab cluster dev environment loaded"
            echo "Tools: kubectl, kubeseal, kustomize, helm, k9s, yq, jq"
          '';
        };
      });
}
