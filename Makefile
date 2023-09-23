PROJECT            = ugperu
ENV                = lab
AWS_DEFAULT_REGION = us-east-1
EKS_VERSION        = 1.27

cluster:
	@cd terraform/ && terraform init
	@export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} && cd terraform/ && terraform apply -var="name=${PROJECT}-${ENV}" -var="eks_version=${EKS_VERSION}" -auto-approve
	@aws eks update-kubeconfig --name ${PROJECT}-${ENV} --region ${AWS_DEFAULT_REGION}



























destroy:
	@cd terraform/ && terraform init
	@export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} && cd terraform/ && terraform destroy -var="name=${PROJECT}-${ENV}" -var="eks_version=${EKS_VERSION}" -auto-approve

cni:
	@kubectl set env daemonset aws-node -n kube-system ENABLE_PREFIX_DELEGATION=true
	@kubectl set env daemonset aws-node -n kube-system WARM_IP_TARGET=1
	@kubectl set env daemonset aws-node -n kube-system MINIMUM_IP_TARGET=250

components:
	@kubectl apply -f manifest/priority-class.yaml
	@kubectl apply -f manifest/metrics-server.yaml

karpenter:
	@kubectl create namespace karpenter
	@export NAME=${PROJECT}-${ENV}-karpenter && envsubst < manifest/service-account.yaml | kubectl apply -f -
	@kubectl annotate serviceaccount -n karpenter ${PROJECT}-${ENV}-karpenter eks.amazonaws.com/role-arn=arn:aws:iam::$(shell aws sts get-caller-identity --query "Account" --output text):role/${PROJECT}-${ENV}-karpenter
	@helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter --version v0.29.2 --namespace karpenter --create-namespace \
	  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::$(shell aws sts get-caller-identity --query "Account" --output text):role/${PROJECT}-${ENV}-karpenter \
	  --set settings.aws.clusterName=${PROJECT}-${ENV} \
      --set settings.aws.defaultInstanceProfile=eks-d8c51ff7-c4b6-17c2-bee9-61b166c7a610 \
      --set settings.aws.interruptionQueueName=${PROJECT}-${ENV} \
      --set controller.resources.requests.cpu=1 \
      --set controller.resources.requests.memory=1Gi \
      --set controller.resources.limits.cpu=1 \
      --set controller.resources.limits.memory=1Gi \
	  --set priorityClassName=high-priority \
      --wait
	@export CLUSTER_NAME=${PROJECT}-${ENV} && envsubst < manifest/provisioner.yaml | kubectl apply -f -

app:
	@kubectl apply -f manifest/app.yaml

testing:
	@kubectl apply -f manifest/load.yaml

clean:
	rm -rf terraform/