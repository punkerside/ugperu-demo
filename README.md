# Scaling up to +10,000 pods on Amazon EKS - AWS UG Perú Conf 2023

[![Build](https://github.com/punkerside/ugperu-demo/actions/workflows/main.yml/badge.svg?branch=main)](https://github.com/punkerside/ugperu-demo/actions/workflows/main.yml)
[![Open Source Helpers](https://www.codetriage.com/punkerside/ugperu-demo/badges/users.svg)](https://www.codetriage.com/punkerside/ugperu-demo)
[![GitHub Issues](https://img.shields.io/github/issues/punkerside/ugperu-demo.svg)](https://github.com/punkerside/ugperu-demo/issues)
[![GitHub Tag](https://img.shields.io/github/tag-date/punkerside/ugperu-demo.svg?style=plastic)](https://github.com/punkerside/ugperu-demo/tags/)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/punkerside/ugperu-demo)

## **Prerequisites**

* [Terraform](https://www.terraform.io/downloads.html)
* [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
* [Helm](https://helm.sh/docs/intro/install/)
* [Kubectl](https://kubernetes.io/es/docs/tasks/tools/install-kubectl/#instalar-kubectl)

## **Deployed resources**

### **1. Amazon AWS**

* Virtual Private Cloud (VPC)
* Identity and Access Management (IAM)
* Elastic Container Service for Kubernetes (EKS)
* Amazon EKS managed node (EKS)

### **2. Kubernetes**

* Metrics Server
* Karpenter
* App + Load

## **Variables**

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `PROJECT` | Project's name | string | `ugperu` | no |
| `ENV` | Environment name | string | `lab` | no |
| `AWS_DEFAULT_REGION` | Amazon AWS Region | string | `us-east-1` | no |
| `EKS_VERSION` | Kubernetes version | string | `1.27` | no |

## **Use**

1. Create EKS cluster

```bash
make cluster
```

2. Configure **CNI**

```bash
make cni
```

3. Install components

```bash
make components
```

4. Install Karpenter

```bash
make karpenter
```

5. Install demo application

```bash
make app
```

6. Install loading app

```bash
make load
```

## **Debug**

1. Observe **pod** scaling

```bash
kubectl get hpa --watch
```

2. Observe **node** scaling

```bash
kubectl get nodes --watch
```

3. Observe states of the **ReplicaSet**

```bash
kubectl get rs --watch
```

4. Observe the state of **Karpenter**

```bash
kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter -c controller
```

## **Destroy**

1. Stop pod scaling

```bash
make reset
```

2. Delete infrastructure

```bash
make destroy
```

## Authors

The module is maintained by [Ivan Echegaray](https://github.com/punkerside)