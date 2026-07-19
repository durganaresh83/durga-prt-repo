# Task 1. Deploy a Python Flask App to AWS EKS using CI/CD

  ## 1. Provision infrastructure

  . This uses an existing VPC and existing subnets in the `us-east-1` region, and creates an EKS cluster
  
<img width="286" height="552" alt="Screenshot 2026-07-19 154606" src="https://github.com/user-attachments/assets/4ec7b965-d47e-4b8d-a048-7f63b14b79c3" />

. aws eks update-kubeconfig --region us-east-1 --name durga-prt-flask-eks-demo
. kubectl get nodes

## 2. App and Dockerfile
`app/app.py` is a minimal Flask service with `/` and `/healthz`. The Dockerfile is a two-stage build (deps built in one layer, copied into a slim runtime image), runs as a non-root user.

<img width="1452" height="736" alt="image" src="https://github.com/user-attachments/assets/8672586a-c933-4500-9f92-c3226006c656" />

# Task 2.  Blue-Green Deployment on EKS using Jenkins and Helm

<img width="292" height="382" alt="image" src="https://github.com/user-attachments/assets/43e291f8-1ecf-42bc-a190-e4788271909c" />

<img width="1537" height="615" alt="image" src="https://github.com/user-attachments/assets/58703e8f-5b4b-4cb9-bd8e-3b25d52c23bc" />

## 1. How Blue-Green works here

. The chart deploys **two independent Deployments** (`nodeapp-blue`, `nodeapp-green`), each with its own static ClusterIP Service for direct smoke-testing. A third Service, `nodeapp-active-svc`, is the only one users actually hit (it's the `LoadBalancer`) — its selector's `color` label is the single switch that decides who gets live traffic.

```
              ┌────────────────────┐
   users ───▶ │ nodeapp-active-svc │──▶ selector: color=blue   ──▶ nodeapp-blue pods (live)
              │  (LoadBalancer)    │        nodeapp-green pods (idle, being tested)
              └────────────────────┘
```

Cutover is just a `helm upgrade --set activeColor=green` — a label selector swap, not a pod restart, so it's near-instant.

## 2. Deploy manually (first time / dry run)
```bash
kubectl create namespace nodeapp
helm upgrade --install nodeapp-blue helm/nodeapp \
  -f helm/nodeapp/values-blue.yaml \
  --namespace nodeapp \
  --set image.repository=<ECR_REPO_URL> \
  --set image.tag=<TAG> \
  --set activeColor=blue
```
This creates the blue Deployment and points `nodeapp-active-svc` at it — blue is now live.

<img width="1407" height="692" alt="image" src="https://github.com/user-attachments/assets/fff0ce44-741a-484a-a111-1164b1ddba06" />

<img width="1576" height="450" alt="image" src="https://github.com/user-attachments/assets/f239fe45-02d1-468e-b602-228f8452b19c" />


# Task 3 — Multi-Environment Microservices Pipeline on EKS

<img width="322" height="437" alt="image" src="https://github.com/user-attachments/assets/6228fb52-f1c5-4157-9c5b-f095a3a6b19a" />

## Structure
```
task3-multienv-microservices/
├── terraform/
│   ├── main.tf, variables.tf         # keyed off terraform.workspace
│   └── environments/{dev,staging,prod}.tfvars
├── services/{service-a,service-b}/   # independent Flask microservices + Dockerfiles
├── k8s/
│   ├── base/                         # shared Deployment/Service (kustomize base)
│   └── {dev, staging, prod}/           # kustomize overlays: namespace, replica counts, image tags
└── Jenkinsfile
```

## 1. Provision infrastructure per environment (Terraform workspaces)
```bash
cd terraform
terraform init

terraform workspace new dev
terraform apply -var-file=environments/dev.tfvars
```
<img width="1540" height="702" alt="image" src="https://github.com/user-attachments/assets/a0ad1fe3-cab0-4bb3-9cb2-e2a3d7f07463" />

## 2. Services and Dockerfiles
`services/service-a` and `services/service-b` are minimal, independently-deployable Flask
apps with `/` and `/healthz`, each with its own Dockerfile (non-root user, slim base image).

<img width="1570" height="410" alt="image" src="https://github.com/user-attachments/assets/48fa52de-329b-49d7-99a4-39a76821c42a" />

<img width="937" height="110" alt="image" src="https://github.com/user-attachments/assets/5b1703f0-da01-461b-8e19-8e67845cae3a" />

## 3. Kubernetes manifests (Kustomize base + overlays)
`k8s/base/` holds the environment-agnostic Deployment/Service definitions. Each environment
overlay (`k8s/dev`, `k8s/staging`, `k8s/prod`):
- sets its own `namespace` (`dev`/`staging`/`prod`),
- patches the `ENVIRONMENT` env var into the containers,
- sets replica counts appropriate to that environment (1 / 2 / 3),
- and (via the pipeline, using `kustomize edit set image`) pins the exact image tag being promoted.

<img width="1552" height="751" alt="image" src="https://github.com/user-attachments/assets/0bbb88e6-3a7f-4fc0-92c0-47338c9dc9b6" />

# The same Terraform code can be reused and can create multiple environments.

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

```bash
aws eks update-kubeconfig --region us-east-1 --name microservices-dev
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

<img width="1247" height="177" alt="image" src="https://github.com/user-attachments/assets/67eaa096-7ba9-489d-a719-2907369432c3" />

# Backend Images
<img width="1562" height="455" alt="image" src="https://github.com/user-attachments/assets/ae15357f-49f8-43a4-ac6e-6cf7be7b9d2d" />

# Frontend Images
<img width="1551" height="447" alt="image" src="https://github.com/user-attachments/assets/3bcb13c5-9653-4b64-8420-4e3850dc59e1" />


## 4. Kubernetes manifests
- `backend-deployment.yaml` / `backend-service.yaml` — 2 replicas, `ClusterIP` (internal
  only — never exposed directly to the internet).
- `frontend-deployment.yaml` / `frontend-service.yaml` — 2 replicas, `LoadBalancer` (the
  only public entry point; nginx inside it reverse-proxies API calls to the backend).

<img width="1481" height="757" alt="image" src="https://github.com/user-attachments/assets/93ddedd9-52c9-46f5-afdc-a2375ad867df" />

## 5. Verify

kubectl get pods -n fullstack-app <br>
kubectl get svc frontend-svc -n fullstack-app <br>
curl http://<FRONTEND-EXTERNAL-IP>/ <br>

<img width="1280" height="552" alt="image" src="https://github.com/user-attachments/assets/34072719-c1f2-4a03-993e-2a644423217b" />

curl http://<FRONTEND-EXTERNAL-IP>/api/hello <br>

<img width="1311" height="367" alt="image" src="https://github.com/user-attachments/assets/9e3f5c34-212f-4443-aceb-10b33df07bc0" />







  


  
