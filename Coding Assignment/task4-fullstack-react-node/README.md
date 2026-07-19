# Task 4 — React Frontend + Node Backend, Shared CI/CD on EKS

## Structure
```
task4-fullstack-react-node/
├── terraform/
│   ├── main.tf                  # root module, wires up shared cluster
│   └── modules/eks-base/        # reusable VPC+EKS+ECR module (one repo per service)
├── frontend/                    # React (Vite) + nginx Dockerfile
├── backend/                     # Node/Express API + Dockerfile
├── k8s/                         # Deployments + Services for both
└── Jenkinsfile                  # builds/tests/deploys both in parallel
```

## 1. Provision shared infrastructure
```bash
cd terraform
terraform init
terraform apply
```
`modules/eks-base` provisions **one** VPC + EKS cluster (shared by both services — the task
calls for shared infra) and **two** ECR repos (`fullstack-react-node/frontend`,
`fullstack-react-node/backend`), so each service's image history/lifecycle is independent
even though the cluster is shared. Passing `service_names = ["frontend", "backend"]` into the
module means adding a third service later is a one-line change.

```bash
aws eks update-kubeconfig --region us-east-1 --name fullstack-react-node
```

## 2. Frontend & backend
- `backend/` — Express API (`/api/hello`, `/healthz`), Alpine-based Dockerfile.
- `frontend/` — React app built with Vite, served by nginx in production. `nginx.conf`
  proxies `/api/*` to `backend-svc:4000` inside the cluster, so the browser only ever talks
  to one origin (no CORS issues in production, and no API URL to hardcode/rebuild for).

Local dev:
```bash
cd backend && npm install && npm start        # localhost:4000
cd frontend && npm install && npm run dev      # localhost:5173, proxies to backend in dev
```

## 3. Jenkins pipeline (shared, parallelized)
Stages: **Checkout → [Backend build/test/push] ∥ [Frontend build/test/push] (parallel) →
Deploy both to EKS.**

Building both services in parallel branches of one stage is what makes this a genuinely
*shared* pipeline rather than two copy-pasted Jenkinsfiles — one trigger, one build number,
one deploy stage that rolls both out together and waits for both rollouts to succeed before
the pipeline goes green.

Required Jenkins setup: `ECR_REGISTRY`, Docker + Node + kubectl + awscli on the agent, and an
IAM identity with ECR push + EKS deploy permissions (same pattern as Tasks 1-3).

## 4. Kubernetes manifests
- `backend-deployment.yaml` / `backend-service.yaml` — 2 replicas, `ClusterIP` (internal
  only — never exposed directly to the internet).
- `frontend-deployment.yaml` / `frontend-service.yaml` — 2 replicas, `LoadBalancer` (the
  only public entry point; nginx inside it reverse-proxies API calls to the backend).

## 5. Verify
```bash
kubectl get pods -n fullstack-app
kubectl get svc frontend-svc -n fullstack-app
curl http://<FRONTEND-EXTERNAL-IP>/
curl http://<FRONTEND-EXTERNAL-IP>/api/hello
```

**[Screenshot placeholder: Jenkins parallel stage view — Backend and Frontend building side by side]**
**[Screenshot placeholder: browser showing the React app with "Backend says: Hello from the Node backend"]**
**[Screenshot placeholder: `kubectl get pods -n fullstack-app` showing both deployments Running]**
**[Screenshot placeholder: two ECR repos in the AWS console]**

## Modularity notes
- Reusable `eks-base` Terraform module means Task 4's infra pattern could be reused for a
  5th, 6th service by just adding to `service_names`.
- Frontend never talks to the backend's public internet at all — it's `ClusterIP`, reached
  only via the nginx proxy — reducing attack surface.
- Independent Dockerfiles/build stages mean either service can be deployed on its own outside
  this pipeline if needed (e.g. a backend-only hotfix job).

## Cleanup
```bash
kubectl delete -f k8s/
cd terraform && terraform destroy
```
