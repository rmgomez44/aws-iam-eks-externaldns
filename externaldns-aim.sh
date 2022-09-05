#! /bin/bash
#
# Script to create AWS IAM Role + Service Account
# and enable/install external DNS on a EKS Cluster
#
# Based on the AWS tutorial
# https://aws.amazon.com/premiumsupport/knowledge-center/eks-set-up-externaldns/
#
# @anotherCloudGuy
####################################################
policy_name="eks_external_dns"
region_code="us-west-2"
srvact_name="external-dns"
policy_text=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": [
        "arn:aws:route53:::hostedzone/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
)
cluster_name=$(aws eks list-clusters --region ${region_code} )
policy_arn=$(aws iam create-policy --policy-name ${policy_name} --politextdocument ${policy_doc} | jq -r '.Policy.Arn')
echo "IAM Policy Created! ${policy_arn}"
echo "Creating the service account ${srvact_name} on kube-system | Cluster name $(cluster_name)" 
eksctl create iamserviceaccount --name ${srvact_name} --namespace kube-system --cluster ${cluster_name} --attach-policy-arn ${policy_arn}  --approve
echo "Creating Cluster Role external-dns"
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: external-dns
rules:
- apiGroups: [""]
  resources: ["services","endpoints","pods"]
  verbs: ["get","watch","list"]
- apiGroups: ["extensions","networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get","watch","list"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["list","watch"]
EOF
echo "Creating Cluster Rolebinding for external-dns"
kubectl apply -f - <<EOF  
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: external-dns-viewer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: external-dns
subjects:
- kind: ServiceAccount
  name: external-dns
  namespace: kube-system
EOF
echo "Deploying pods for external-dns"
kubectl apply -f - <<EOF  
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-dns
  namespace: kube-system
spec:
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: external-dns
  template:
    metadata:
      labels:
        app: external-dns
    spec:
      serviceAccountName: external-dns
      containers:
      - name: external-dns
        image: k8s.gcr.io/external-dns/external-dns:v0.10.2
        args:
        - --source=service
        - --source=ingress
        - --provider=aws
        - --policy=upsert-only # would prevent ExternalDNS from deleting any records, omit to enable full synchronization
        - --aws-zone-type=
        - --registry=txt
      securityContext:
        fsGroup: 65534 # For ExternalDNS to be able to read Kubernetes and AWS token files
EOF
