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


