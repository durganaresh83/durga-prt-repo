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

<img width="322" height="577" alt="image" src="https://github.com/user-attachments/assets/a79075ce-9693-44b5-9870-8240dcb295bc" />

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
<img width="1555" height="717" alt="image" src="https://github.com/user-attachments/assets/9fc40227-ab27-4461-aaad-2ad26ed0b156" />


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

# Task 5 — High Availability App with HPA + Cluster Autoscaler on EKS

<img width="322" height="517" alt="image" src="https://github.com/user-attachments/assets/3a5e29a9-ab70-4b4f-83c6-a50e7336c920" />

## Structure
```
task5-ha-autoscaling/
├── terraform/          # EKS across 3 AZs, ASG tagged for Cluster Autoscaler, IRSA role
├── app/                # Flask app with a CPU-heavy /cpu-work endpoint for load testing
├── k8s/
│   ├── deployment.yaml, service.yaml, pdb.yaml
│   ├── hpa.yaml               # Horizontal Pod Autoscaler
│   ├── cluster-autoscaler.yaml
│   └── metrics-server.yaml    # notes/instructions (installed from upstream manifest)
└── Jenkinsfile
```

## Two layers of autoscaling
- **HPA (pods)** — adds/removes *pod replicas* of the app based on CPU/memory utilization. Fast (seconds), but capped by whatever capacity the nodes already have.
- **Cluster Autoscaler (nodes)** — adds/removes *EC2 nodes* when pods are unschedulable due to insufficient capacity, or removes underutilized nodes. Slower (minutes — an EC2 instance has to boot and join), but unlocks headroom beyond the current node count.

## 1. Provision infrastructure
```bash
cd terraform
terraform init && terraform apply
```

This creates:
- A VPC across **3 AZs** (public/private subnets each) for real fault tolerance.
- An EKS managed node group, `desired=3 / min=3 / max=10`, private subnets tagged
  `k8s.io/cluster-autoscaler/enabled=true` and `k8s.io/cluster-autoscaler/<cluster>=owned` —
  The tags the Cluster Autoscaler relies on for auto-discovery.
- An IAM role for the Cluster Autoscaler pod, trust-scoped via OIDC/IRSA to only
  `system:serviceaccount:kube-system:cluster-autoscaler` (least privilege — no static keys
  needed inside the pod).
- An ECR repo for the app image.

```bash
terraform output cluster_autoscaler_role_arn
aws eks update-kubeconfig --region us-east-1 --name ha-autoscale-demo
```

## 2. App and Dockerfile
`app/app.py` is a small Flask app with a `/cpu-work` endpoint that does real CPU-bound hashing
work — useful for generating load, actually to trigger HPA scale-out during a demo, rather than
needing an external load generator to guess at CPU usage.

<img width="1557" height="445" alt="image" src="https://github.com/user-attachments/assets/2203a780-5c25-4c6f-89d5-6e6ca1046e40" />

## 3. Deploy metrics-server (prerequisite for HPA)
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl top nodes   # should return numbers once metrics-server is ready (~1 min)
```
<img width="1502" height="692" alt="image" src="https://github.com/user-attachments/assets/ef455065-b8e3-4963-9b69-12614326ff22" />


## 4. Deploy the app, HPA, PDB, and Cluster Autoscaler
```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/deployment.yaml   # after substituting the ECR image
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/pdb.yaml
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/cluster-autoscaler.yaml   # after substituting role ARN + cluster name
```

<img width="1502" height="631" alt="image" src="https://github.com/user-attachments/assets/9af96473-0efb-4776-9ff8-621496164a95" />

<img width="1452" height="610" alt="image" src="https://github.com/user-attachments/assets/e0f7e594-0443-441f-8bc4-53568ae8a54a" />

## 5. Load test to prove it scales

```bash
kubectl run load-generator --rm -i --tty --restart=Never --image=busybox -- \
  /bin/sh -c "while true; do wget -q -O- http://ha-app-svc.ha-app.svc.cluster.local/cpu-work; done"

watch kubectl get hpa ha-app-hpa -n ha-app
watch kubectl get nodes
```
**Expect**: HPA replica count climbs toward `**maxReplicas: 20**` as CPU utilization crosses 60%; once existing nodes are full, `kubectl get pods -n ha-app` will show some `Pending`, and within a few minutes the node count grows (Cluster Autoscaler adding capacity) and those pods are scheduled.
  
<img width="1400" height="485" alt="image" src="https://github.com/user-attachments/assets/eea9cd0f-c613-459d-9157-a2d4a0d6f4d5" />

. To generate the load.

<img width="1422" height="660" alt="image" src="https://github.com/user-attachments/assets/067f7fe9-178c-469b-ac31-09c2705fc42c" />

. The number of pods is increased based on the load.

<img width="1477" height="682" alt="image" src="https://github.com/user-attachments/assets/6c8e2082-c032-48e6-ae5c-e792ed51c82b" />

The Number of pods is increased to 11. Check the search bar for the count

<img width="1460" height="672" alt="image" src="https://github.com/user-attachments/assets/bece14bf-3eda-4f37-b293-36ca4cfa956d" />

. **Action**: launched 5 parallel busybox load pods hitting /cpu-work for ~5 minutes. <br>
. **Result**: ha-app-hpa scaled from 3 → 7 → 11 replicas (peak); CPU reported well above the 60% target during the run (samples up to ~152%). <br>
. **Load pods**: completed and cleaned up after the test. <br>
. **Cluster Autoscaler**: no node count increase observed during this window — nodes stayed at current capacity (to trigger node autoscaling, you need sustained unschedulable pods or a higher sustained load that fills node capacity). <br>
