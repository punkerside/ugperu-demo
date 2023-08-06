PROJECT                = ugperu
ENV                    = lab
AWS_DEFAULT_REGION     = us-east-1
EKS_VERSION            = 1.27
KARPENTER_VERSION      = v0.29.2
KARPENTER_IAM_ROLE_ARN = arn:aws:iam::509472714099:role/ugperu-lab

cluster:
	@cd terraform/ && terraform init
	@export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} && cd terraform/ && terraform apply -var="name=${PROJECT}-${ENV}" -var="eks_version=${EKS_VERSION}" -auto-approve
	@aws eks update-kubeconfig --name ${PROJECT}-${ENV} --region ${AWS_DEFAULT_REGION}

metrics-server:
	@kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.6.4/components.yaml

destroy:
	@cd terraform/ && terraform init
	@export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} && cd terraform/ && terraform destroy -var="name=${PROJECT}-${ENV}" -var="eks_version=${EKS_VERSION}" -auto-approve

karpenter:
	@kubectl apply -f scripts/namespace.yaml
	@export NAME=${PROJECT}-${ENV}-karpenter && envsubst < scripts/service-account.yaml | kubectl apply -f -
	@kubectl annotate serviceaccount -n karpenter ${PROJECT}-${ENV}-karpenter eks.amazonaws.com/role-arn=arn:aws:iam::$(shell aws sts get-caller-identity --query "Account" --output text):role/${PROJECT}-${ENV}-karpenter
	@helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter --version ${KARPENTER_VERSION} --namespace karpenter --create-namespace \
	  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::$(shell aws sts get-caller-identity --query "Account" --output text):role/${PROJECT}-${ENV}-karpenter \
	  --set settings.aws.clusterName=${PROJECT}-${ENV} \
      --set settings.aws.defaultInstanceProfile=eks-6ec4e5f7-cd60-eae7-3dac-c74b89ff8b11 \
      --set settings.aws.interruptionQueueName=${PROJECT}-${ENV} \
      --set controller.resources.requests.cpu=1 \
      --set controller.resources.requests.memory=1Gi \
      --set controller.resources.limits.cpu=1 \
      --set controller.resources.limits.memory=1Gi \
      --wait
	@export CLUSTER_NAME=${PROJECT}-${ENV} && envsubst < scripts/provisioner.yaml | kubectl apply -f -

deploy:
	@kubectl apply -f manifest/deployment.yaml
	@kubectl apply -f manifest/service.yaml
	@kubectl apply -f manifest/hpa.yaml

testing:
	@kubectl apply -f scripts/testing.yaml