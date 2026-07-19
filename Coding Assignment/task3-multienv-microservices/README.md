# Task 3 — Multi-Environment Microservices Pipeline on EKS

## Structure
```
task3-multienv-microservices/
├── terraform/
│   ├── main.tf, variables.tf         # keyed off terraform.workspace
│   └── environments/{dev,staging,prod}.tfvars
├── services/{service-a,service-b}/   # independent Flask microservices + Dockerfiles
├── k8s/
│   ├── base/                         # shared Deployment/Service (kustomize base)
│   └── {dev,staging,prod}/           # kustomize overlays: namespace, replica counts, image tags
└── Jenkinsfile
```

## 1. Provision infrastructure per environment (Terraform workspaces)
```bash
cd terraform
terraform init

terraform workspace new dev
terraform apply -var-file=environments/dev.tfvars

terraform workspace new staging
terraform apply -var-file=environments/staging.tfvars

terraform workspace new prod
terraform apply -var-file=environments/prod.tfvars
```
Each workspace gets its **own isolated state, VPC, EKS cluster, and node group** (dev uses
t3.small/1-2 nodes, staging t3.medium/1-3, prod t3.large/3-6 for HA). All three environments
share the same ECR repositories (`microservices/service-a`, `microservices/service-b`) —
images are differentiated by tag, not by repo, which is what makes "build once, promote
everywhere" possible.

```bash
terraform workspace list
terraform workspace show
```

## 2. Services and Dockerfiles
`services/service-a` and `services/service-b` are minimal, independently-deployable Flask
apps with `/` and `/healthz`, each with its own Dockerfile (non-root user, slim base image).

## 3. Kubernetes manifests (Kustomize base + overlays)
`k8s/base/` holds the environment-agnostic Deployment/Service definitions. Each environment
overlay (`k8s/dev`, `k8s/staging`, `k8s/prod`):
- sets its own `namespace` (`dev`/`staging`/`prod`),
- patches the `ENVIRONMENT` env var into the containers,
- sets replica counts appropriate to that environment (1 / 2 / 3),
- and (via the pipeline, using `kustomize edit set image`) pins the exact image tag being promoted.

Preview any environment's fully-rendered manifests locally:
```bash
kubectl kustomize k8s/staging
```

## 4. Jenkins pipeline — promotion strategy
Stages: **Checkout → Build & Test (matrix: service-a / service-b, in parallel) → Deploy to
dev → [manual approval] → Deploy to staging → [manual approval, `release-managers` group] →
Deploy to prod.**

Key principle: **the image is built and pushed to ECR exactly once**, tagged with the short
git commit SHA. Every subsequent environment deploy reuses that identical, already-tested
tag — dev, staging, and prod always end up running the exact same artifact, just at
different points in time. This avoids "it worked in staging but the prod build was
different" drift.

Required Jenkins setup:
- `ECR_REGISTRY` env var/credential (`<account_id>.dkr.ecr.us-east-1.amazonaws.com`).
- `kustomize` and `kubectl` on the agent.
- An IAM identity able to `aws eks update-kubeconfig` + apply against all three clusters
  (or use per-cluster access entries mapped to the same Jenkins role).
- Two manual `input` gates enforce human sign-off before staging and before prod; the prod
  gate is restricted to a `release-managers` group.

## 5. Verify
```bash
kubectl get pods -n dev
kubectl get pods -n staging
kubectl get pods -n prod
```

**[Screenshot placeholder: Jenkins matrix stage view — service-a/service-b built in parallel]**
**[Screenshot placeholder: Jenkins pipeline paused at the "Promote to staging" input gate]**
**[Screenshot placeholder: `kubectl get pods -n prod` after successful promotion]**
**[Screenshot placeholder: `terraform workspace list` showing dev/staging/prod]**

## Notes on environment segregation
- Separate Terraform workspaces → separate state files → a mistake in `dev` cannot corrupt
  `prod` state or accidentally modify prod infrastructure.
- Separate EKS clusters (not just namespaces) per environment → blast-radius isolation and
  the ability to give prod stricter network/IAM policies without affecting dev velocity.
- Shared ECR + kustomize base → no duplicated Dockerfile/manifest logic; only the parts that
  actually differ per environment (replicas, namespace, image tag) are overridden.

## Cleanup
```bash
for env in dev staging prod; do
  kubectl delete -k k8s/$env
done
cd terraform
for ws in dev staging prod; do
  terraform workspace select $ws
  terraform destroy -var-file=environments/$ws.tfvars
done
```
