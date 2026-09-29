SHELL := /bin/bash
.SHELLFLAGS := -e -o pipefail -c

TF := terraform -chdir=terraform
TAG ?= v8
LOCAL_IMAGE := localhost:4566/hello-eks:$(TAG)

export AWS_ACCESS_KEY_ID := test
export AWS_SECRET_ACCESS_KEY := test
export AWS_DEFAULT_REGION := us-east-1
export AWS_ENDPOINT_URL := http://localhost:4566
export AWS_EC2_METADATA_DISABLED := true
export KUBECONFIG := $(CURDIR)/.kubeconfig-ministack

.PHONY: help up init validate plan apply output destroy build push kubeconfig deploy status logs port-forward down

help:
	@echo "Infraestrutura: make up init validate plan apply output destroy down"
	@echo "Imagem:         make push TAG=v8 (executa build antes do push)"
	@echo "Kubernetes:     make kubeconfig deploy status logs port-forward"

up:
	docker compose up -d

init:
	$(TF) init

validate: init
	$(TF) validate

plan: validate
	$(TF) plan

apply: validate
	$(TF) apply -auto-approve

output:
	$(TF) output

destroy: init
	$(TF) destroy

build:
	docker build -t $(LOCAL_IMAGE) app

push: build
	docker push $(LOCAL_IMAGE)

kubeconfig:
	aws eks update-kubeconfig --name ministack-lab --alias ministack-lab --kubeconfig "$(KUBECONFIG)"

deploy: kubeconfig
	kubectl apply -f k8s/cloudwatch.yaml -f k8s/configmap.yaml -f k8s/app.yaml
	kubectl rollout status daemonset/hello-eks-logs -n kube-system --timeout=180s
	kubectl rollout status deployment/hello-eks --timeout=180s

rollout-status: kubeconfig
	kubectl rollout status deployment/hello-eks --timeout=180s

status:
	kubectl get nodes -o wide
	kubectl get pods -o wide

logs:
	aws logs tail /eks/ministack-lab/hello-eks --since 1h

port-forward:
	kubectl port-forward svc/hello-eks 5001:5001

down:
	docker compose down
