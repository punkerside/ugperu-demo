PROJECT            = ugperu
ENV                = dev

AWS_DEFAULT_REGION = us-east-1
EKS_VERSION        = 1.27

# creando cluster k8s
cluster:
	@cd terraform/ && \
	  terraform init
	@export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} && cd terraform/ && terraform apply \
	  -var="project=${PROJECT}" \
	  -var="env=${ENV}" \
	  -var="eks_version=${EKS_VERSION}" -auto-approve
	@rm -rf ~/.kube/
	@aws eks update-kubeconfig --name ${PROJECT}-${ENV} --region ${AWS_DEFAULT_REGION}

# instalando metrics server
metrics-server:
	@kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.6.3/components.yaml

# instalando cluster autoscaler
cluster-autoscaler:
	export EKS_NAME=$(PROJECT)-$(ENV) EKS_VERSION=$(shell curl -s https://api.github.com/repos/kubernetes/autoscaler/releases | grep tag_name | grep cluster-autoscaler | grep $(EKS_VERSION) | cut -d '"' -f4 | cut -d "-" -f3 | head -1) && envsubst < scripts/cluster-autoscaler-autodiscover.yaml | kubectl apply -f -
#	@kubectl -n kube-system annotate deployment.apps/cluster-autoscaler cluster-autoscaler.kubernetes.io/safe-to-evict="false" --overwrite

# desplegando aplicacion de carga
deploy:
	@kubectl apply -f manifest/deployment.yaml
	@kubectl apply -f manifest/service.yaml
	@kubectl apply -f manifest/hpa.yaml

load:
	@kubectl apply -f scripts/load.yaml

# destruyendo cluster k8s
destroy:
	@export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} && cd terraform/ && terraform destroy \
	  -var="project=${PROJECT}" \
	  -var="env=${ENV}" \
	  -var="eks_version=${EKS_VERSION}" -auto-approve

ekscluster:
	eksctl delete cluster -f scripts/cluster.yaml