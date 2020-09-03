{ self, lib, pkgs, config, ... }:
let
  inherit (import ./security-group-rules.nix { inherit config pkgs lib; })
    securityGroupRules;

  inherit (config) cluster;
  inherit (cluster.vpc) subnets;

  bitte = self.inputs.bitte;
in
{
  imports = [ ./iam.nix ];

  cluster = {
    name = "tutorial-testnet";
    domain = "bitte-tutorial-2.project42.iohkdev.io";
    s3Bucket = "bitte-tutorial";
    s3CachePubKey = "tutorial-testnet-0:2vNrvBq1ilG7CJK265wASZeqRsdfjiYx22f9wm/qKxc=";
    kms = "arn:aws:kms:ap-southeast-2:596662952274:key/4534c14c-a9b9-4922-a015-a52ee57582f1";
    adminNames = [ "shay.bergmann" "manveru" "samuel.evans-powell" ];
    terraformOrganization = "iohk-midnight";

    flakePath = ../..;
    
    instances = {
      core-1 = {
        instanceType = "t3a.medium";
        privateIP = "172.16.0.10";
        route53.domains = [ "consul" "vault" "nomad" ];
        subnet = subnets.prv-1;

        securityGroupRules = {
          inherit (securityGroupRules)
            internet internal ssh http https haproxyStats vault-http grpc;
        };

        modules = [
          (bitte + /profiles/core.nix)
          (bitte + /profiles/bootstrapper.nix)
          ./secrets.nix
        ];

        initialVaultSecrets = {
          consul = ''
            sops --decrypt --extract '["encrypt"]' ${
              config.secrets.encryptedRoot + "/consul-clients.json"
            } \
            | vault kv put kv/bootstrap/clients/consul encrypt=-
          '';

          nomad = ''
            sops --decrypt --extract '["server"]["encrypt"]' ${
              config.secrets.encryptedRoot + "/nomad.json"
            } \
            | vault kv put kv/bootstrap/clients/nomad encrypt=-
          '';
        };
      };

      core-2 = {
        instanceType = "t3a.medium";
        privateIP = "172.16.1.10";
        subnet = subnets.prv-2;

        modules = [ (bitte + /profiles/core.nix) ./secrets.nix ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh;
        };
      };

      core-3 = {
        instanceType = "t3a.medium";
        privateIP = "172.16.2.10";
        subnet = subnets.prv-3;

        modules = [ (bitte + /profiles/core.nix) ./secrets.nix ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh;
        };
      };

      monitoring = {
        instanceType = "t3a.large";
        privateIP = "172.16.0.20";
        subnet = subnets.prv-1;
        route53.domains = [ "monitoring" ];

        modules = [ (bitte + /profiles/monitoring.nix) ./secrets.nix ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh;
        };
      };
    };  
  };
}
