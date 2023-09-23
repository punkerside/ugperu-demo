PROJECT            = ugperu
ENV                = lab
AWS_DEFAULT_REGION = us-east-1
EKS_VERSION        = 1.27

cluster:
	@cd terraform/ && terraform init
	@export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} && cd terraform/ && terraform apply -var="name=${PROJECT}-${ENV}" -var="eks_version=${EKS_VERSION}" -auto-approve
	@aws eks update-kubeconfig --name ${PROJECT}-${ENV} --region ${AWS_DEFAULT_REGION}

cni:
	@kubectl set env daemonset aws-node -n kube-system ENABLE_PREFIX_DELEGATION=true
	@kubectl set env daemonset aws-node -n kube-system WARM_IP_TARGET=1
	@kubectl set env daemonset aws-node -n kube-system MINIMUM_IP_TARGET=250

components:
	@kubectl apply -f k8s/metrics-server.yaml

karpenter:
	$(eval INSTANCE_ID = $(shell aws ec2 describe-instances  --query "Reservations[*].Instances[*].{Id:InstanceId,Name:Tags[?Key=='Name']|[0].Value,Status:State.Name}" --filters Name=instance-state-name,Values=running  --region us-east-1 | jq -r .[0][0].Id))
	$(eval PROFILE_NAME = $(shell aws ec2 describe-iam-instance-profile-associations --region us-east-1 --filters "Name=instance-id,Values=${INSTANCE_ID}" | jq -r .IamInstanceProfileAssociations[].IamInstanceProfile.Arn | cut -d"/" -f2))
#	@kubectl create namespace karpenter
	@export NAME=${PROJECT}-${ENV}-karpenter && envsubst < k8s/service-account.yaml | kubectl apply -f -
	@kubectl annotate serviceaccount -n karpenter ${PROJECT}-${ENV}-karpenter eks.amazonaws.com/role-arn=arn:aws:iam::$(shell aws sts get-caller-identity --query "Account" --output text):role/${PROJECT}-${ENV}-karpenter
	@helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter --version v0.30.0 --namespace karpenter --create-namespace \
	  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::$(shell aws sts get-caller-identity --query "Account" --output text):role/${PROJECT}-${ENV}-karpenter \
	  --set settings.aws.clusterName=${PROJECT}-${ENV} \
      --set settings.aws.defaultInstanceProfile=${PROFILE_NAME} \
      --set settings.aws.interruptionQueueName=${PROJECT}-${ENV} \
      --set controller.resources.requests.cpu=1 \
      --set controller.resources.requests.memory=1Gi \
      --set controller.resources.limits.cpu=1 \
      --set controller.resources.limits.memory=1Gi \
	  --set priorityClassName=high-priority \
      --wait
	@export CLUSTER_NAME=${PROJECT}-${ENV} && envsubst < k8s/provisioner.yaml | kubectl apply -f -

app:
	@kubectl apply -f k8s/app.yaml

load:
	@kubectl apply -f k8s/load.yaml

reset:
	@kubectl apply -f k8s/reset.yaml

destroy:
	@cd terraform/ && terraform init
	@export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} && cd terraform/ && terraform destroy -var="name=${PROJECT}-${ENV}" -var="eks_version=${EKS_VERSION}" -auto-approve

clean:
	@rm -rf terraform/.terraform/
	@rm -rf terraform/.terraform.lock.hcl
	@rm -rf terraform/terraform.tfstate
	@rm -rf terraform/terraform.tfstate.backup