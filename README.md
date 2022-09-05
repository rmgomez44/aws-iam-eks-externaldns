# aws-iam-eks-externaldns
Bash script to create ans IAM role + services account on EKS Cluster

This is an all-in-one script with the specific purpose of enabling External DNS addon on an EKS Cluster

This addon can redirect route53 hosted zone records with (internal) application load balancers. the IAM role has permission to add or update DNS records to let this addon create the route53 records by itself.
