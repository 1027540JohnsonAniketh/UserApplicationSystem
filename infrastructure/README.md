# infrastructure
<pre>
Prerequisites and steps to get started:
1)Install Terraform
2)Install AWS CLI and configure AWS CLI dev and prod profiles accordingly
3)To create your resources in aws,we need to write the appropriate code in the main.tf file and run the following terraform commands
  i)terraform init
 ii)terraform apply
4)After all the work is done we to destroy the resources run the "terraform destroy" command.
5)To create multiple vpcs we make use of workspaces and we run the following commads:
  i)To create a workspace:
    terraform workspace new workspace_name
 ii)To switch to a workspace:
    terraform workspace select workspace_name
iii)To delete a workspace
    terraform workspace delete workspace_name 
</pre>
<pre>
Command to import certificate:
aws acm import-certificate --certificate fileb://certificate_name.pem \
      --certificate-chain fileb://certificatechain_name.pem \
      --private-key fileb://privateKkey_name.pem \
      --profile prod
</pre>

