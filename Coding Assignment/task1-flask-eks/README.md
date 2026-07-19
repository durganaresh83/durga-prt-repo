# Task 1 — Flask App on AWS EKS with Jenkins CI/CD

## Structure
```
task1-flask-eks/
├── terraform/          # VPC, EKS, ECR
├── app/                # Flask app + Dockerfile + tests
├── k8s/                # Deployment, Service, Namespace
└── Jenkinsfile
```

## 1. Provision infrastructure
```bash
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```
This uses an existing VPC (`vpc-0f6478cf22f8a5021`) and existing subnets
(`subnet-0a2360af89c7f9ada`, `subnet-04e8719e5336b60d6`) in `us-east-1`, and creates an EKS cluster
(1.36) with a managed node group (t3.medium, 1-4 nodes autoscaling), plus an ECR repo with
image scanning + a 10-image lifecycle policy.

Point kubectl at the new cluster:
```bash
aws eks update-kubeconfig --region us-east-1 --name durga-prt-flask-eks-demo
kubectl get nodes
```

## 2. App and Dockerfile
`app/app.py` is a minimal Flask service with `/` and `/healthz`. The Dockerfile is a
two-stage build (deps built in one layer, copied into a slim runtime image), runs as a
non-root user, and serves via gunicorn.

Local test:
```bash
cd app
pip install -r requirements.txt
pytest
docker build -t flask-app:local .
docker run -p 5000:5000 flask-app:local
curl localhost:5000/healthz
```

## 3. Jenkins pipeline
Stages: **Checkout → Install & Unit Test → Build Image → Trivy Scan → Push to ECR → Deploy to EKS**.

Required Jenkins setup:
- Jenkins agent with `docker`, `awscli`, `kubectl`, `python3`, `trivy` installed.
- Credential `aws-jenkins-creds` (AWS access key/secret, or better: an IAM role attached to
  the Jenkins EC2 instance / Jenkins running as a pod with IRSA).
- Set `ECR_REPO` in the Jenkinsfile to the `ecr_repository_url` Terraform output.
- Jenkins IAM identity needs: `ecr:GetAuthorizationToken`, `ecr:PutImage`, `ecr:BatchCheckLayerAvailability`,
  `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`, and EKS access
  (via an entry in the cluster's `aws-auth` ConfigMap / EKS access entry mapping to a role
  that can `kubectl apply`).

Each build tags the image with `${BUILD_NUMBER}` for traceability and pushes only after tests
pass, then substitutes the image into `k8s/deployment.yaml` and applies it with a rolling
update (`maxSurge: 1, maxUnavailable: 0` = zero-downtime).

## 4. Kubernetes manifests
- `namespace.yaml` — isolates the app in its own `durga-prt-flask-app` namespace.
- `deployment.yaml` — 2 replicas, resource requests/limits, readiness+liveness probes on
  `/healthz`, `runAsNonRoot` security context, rolling update strategy.
- `service.yaml` — `LoadBalancer` type, provisions an AWS NLB/ELB automatically via the
  in-tree/AWS Load Balancer Controller.

## 5. Verify
```bash
kubectl get pods -n durga-prt-flask-app
kubectl get svc durga-prt-flask-app-svc -n durga-prt-flask-app
curl http://<EXTERNAL-IP>/
```

**[Screenshot placeholder: `kubectl get pods -n durga-prt-flask-app` showing 2/2 Running]**
**[Screenshot placeholder: Jenkins pipeline stage view, all green]**
**[Screenshot placeholder: `curl` output from the LoadBalancer endpoint]**
**[Screenshot placeholder: ECR console showing pushed image tags]**

## Security & best-practice notes
- Non-root container user, read-only-friendly image, resource limits set to avoid noisy-neighbor issues.
- ECR image scanning on push + immutable tags prevent tag-overwrite attacks.
- Terraform state stored remotely in S3 with DynamoDB locking (edit bucket name in `providers.tf`).
- EKS secrets encrypted at rest via a dedicated KMS key.
- Least-privilege IAM roles per component (cluster role vs. node role vs. Jenkins role) rather
  than one shared role.

## Cleanup
```bash
kubectl delete -f k8s/
cd terraform && terraform destroy
```
