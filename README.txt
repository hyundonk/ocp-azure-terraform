# README.txt

This terraform scripts deploys Azure resources for OCP infrastructure.

The scripts are comprised with 5 modules. Each module deploys azure resources as below.

1. network/network.tf 
 - VNET, subnets 
 - NSGs
 - a Azure Private DNS zone 

2. ocpcluster/cluster.tf
 - VM Image (RHEL7.5)
 - VMs for master nodes, router nodes, infra nodes, app nodes, and bastion node
 - External LB for master VMs
 - Internal LB for master VMs
 - External LB for router VMs
 - Availability Sets for VMs
 - Network Interfaces for VMs
 - a Public IP for master LB
 - a Public IP for router LB
 - a Public IP for bastion VM

3. dnszone/dnszone.tf
 - a Azure Public DNS zone

4. vpn/vpn.tf
 - a Virtual Network Gateway and connection to on-premises DC.

5. routerinternallb/routerinternallb.tf
 - Internal LB for router VMs


Limitation
1. Current stable version of terraform doesn't support dependencies between modules and each module have to be deployed separately as described in "deployment instruction" section below. This would be fixed at terraform version 0.12.0 which is expected released soon. With terraform 0.12.0, it would be able to deploy all modules with master terraform file(main.tf). Refer https://github.com/hashicorp/terraform/issues/16983 


Deployment Instruction
Note: 
 - Deploy network module first and then deploy ocpcluster module which depends on network module. Other modules doesn't have dependencies between themselves.
 - "terraform plan" and "terraform apply" reads variable definitions from terraform.tfvars file which will be distributed separately. Modify it before deployment if needed. Note that it contains secrets such as subscription ID, storage account name, storage account key, network address space, VM adminname and password as well as VPN connection shared key and do not share this file to un-authorized person. 

1. network module deployment
 $ cd network
 $ terraform init -backend-config="storage_account_name=<value>" -backend-config="access_key=<enter storage account access key here>"
 $ terraform plan -var-file=../terraform.tfvars
 $ terraform apply -var-file=../terraform.tfvars 

2. ocpcluster module deployment
 $ cd ../ocpcluster
 $ terraform init -backend-config="storage_account_name=<value>" -backend-config="access_key=<enter storage account access key here>"
 $ terraform plan -var-file=../terraform.tfvars
 $ terraform apply -var-file=../terraform.tfvars 

3. dnszone module deployment
 $ cd dnszone
 $ terraform init -backend-config="storage_account_name=<value>" -backend-config="access_key=<enter storage account access key here>"
 $ terraform plan -var-file=../terraform.tfvars
 $ terraform apply -var-file=../terraform.tfvars 

4. vpn module deployment
 $ cd vpn
 $ terraform init -backend-config="storage_account_name=<value>" -backend-config="access_key=<enter storage account access key here>"
 $ terraform plan -var-file=../terraform.tfvars
 $ terraform apply -var-file=../terraform.tfvars 

5. routerinternallb module deployment
 $ cd routerinternallb
 $ terraform init -backend-config="storage_account_name=<value>" -backend-config="access_key=<enter storage account access key here>"
 $ terraform plan -var-file=../terraform.tfvars
 $ terraform apply -var-file=../terraform.tfvars 

Note) 
There are cases to add variables on existing module to refer them from other modules. To add output variable on existing terraform modules without applying it, use "terrafrom refresh" instead of "terraform apply".




