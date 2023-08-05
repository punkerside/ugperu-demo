PROJECT            = ugperu
ENV                = lab
AWS_DEFAULT_REGION = us-east-1
EKS_VERSION        = 1.27

KARPENTER_VERSION          = v0.29.2
CLUSTER_NAME               = ugperu-dev
AWS_ACCOUNT_ID             = 509472714099

KARPENTER_IAM_ROLE_ARN     = arn:aws:iam::509472714099:role/eksctl-ugperu-dev-cluster-ServiceRole-ERGZYUPMB381
KARPENTER_IAM_PROFILE_NAME = eks-32c4dcc4-1553-d71f-6f26-3426600f9be9

cluster:
	eksctl delete cluster -f cluster.yaml

metrics-server:
	@kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.6.4/components.yaml

karpenter:
	helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter --version ${KARPENTER_VERSION} --namespace karpenter --create-namespace \
	 --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=${KARPENTER_IAM_ROLE_ARN} \
	 --set settings.aws.clusterName=${CLUSTER_NAME} \
	 --set settings.aws.defaultInstanceProfile=${KARPENTER_IAM_PROFILE_NAME} \
	 --set settings.aws.interruptionQueueName=${CLUSTER_NAME} \
	 --wait

delete:
	eksctl delete cluster -f cluster.yaml

# # creando cluster k8s
# cluster:
# 	@cd terraform/ && terraform init
# 	@export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} && cd terraform/ && terraform apply -var="name=${PROJECT}-${ENV}" -var="eks_version=${EKS_VERSION}" -auto-approve
# 	@aws eks update-kubeconfig --name ${PROJECT}-${ENV} --region ${AWS_DEFAULT_REGION}

# # destruyendo cluster k8s
# destroy:
# 	@export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} && cd terraform/ && terraform destroy -var="name=${PROJECT}-${ENV}" -var="eks_version=${EKS_VERSION}" -auto-approve



# # desplegando aplicacion de carga
# deploy:
# 	@kubectl apply -f manifest/deployment.yaml
# 	@kubectl apply -f manifest/service.yaml
# 	@kubectl apply -f manifest/hpa.yaml

# load:
# 	@kubectl apply -f scripts/load.yaml

# # instalando cluster autoscaler
# cluster-autoscaler:
# 	export EKS_NAME=$(PROJECT)-$(ENV) EKS_VERSION=$(shell curl -s https://api.github.com/repos/kubernetes/autoscaler/releases | grep tag_name | grep cluster-autoscaler | grep $(EKS_VERSION) | cut -d '"' -f4 | cut -d "-" -f3 | head -1) && envsubst < scripts/cluster-autoscaler-run-on-control-plane.yaml | kubectl apply -f -
