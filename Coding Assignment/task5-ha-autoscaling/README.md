# Task 5 — High Availability App with HPA + Cluster Autoscaler on EKS

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
- **HPA (pods)** — adds/removes *pod replicas* of the app based on CPU/memory utilization.
  Fast (seconds), but capped by whatever capacity the nodes already have.
- **Cluster Autoscaler (nodes)** — adds/removes *EC2 nodes* when pods are unschedulable due
  to insufficient capacity, or removes nodes that are underutilized. Slower (minutes — an EC2
  instance has to boot and join), but unlocks headroom beyond the current node count.
  Together: HPA scales pods up until nodes are full → Cluster Autoscaler notices unschedulable
  pods → adds a node → HPA's new pods land on it.

## 1. Provision infrastructure
```bash
cd terraform
terraform init && terraform apply
```
This creates:
- A VPC across **3 AZs** (public/private subnets each) for real fault tolerance.
- An EKS managed node group, `desired=3 / min=3 / max=10`, private subnets tagged
  `k8s.io/cluster-autoscaler/enabled=true` and `k8s.io/cluster-autoscaler/<cluster>=owned` —
  the tags Cluster Autoscaler's auto-discovery relies on.
- An IAM role for the Cluster Autoscaler pod, trust-scoped via OIDC/IRSA to only
  `system:serviceaccount:kube-system:cluster-autoscaler` (least privilege — no static keys
  needed inside the pod).
- An ECR repo for the app image.

```bash
terraform output cluster_autoscaler_role_arn
aws eks update-kubeconfig --region us-east-1 --name ha-autoscale-demo
```
Substitute that ARN into `k8s/cluster-autoscaler.yaml`'s ServiceAccount annotation, and the
cluster name into its `--node-group-auto-discovery` arg, before applying (the Jenkinsfile's
`sed` step, or do it manually — see below).

## 2. App and Dockerfile
`app/app.py` is a small Flask app with a `/cpu-work` endpoint that does real CPU-bound hashing
work — useful for generating load to actually trigger HPA scale-out during a demo, rather than
needing an external load generator to guess at CPU usage.

## 3. Deploy metrics-server (prerequisite for HPA)
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl top nodes   # should return numbers once metrics-server is ready (~1 min)
```

## 4. Deploy the app, HPA, PDB, and Cluster Autoscaler
```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/deployment.yaml   # after substituting the ECR image
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/pdb.yaml
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/cluster-autoscaler.yaml   # after substituting role ARN + cluster name
```

## 5. Jenkins pipeline
Stages: **Checkout → Install & Test → Build & Push Image → Ensure autoscaling add-ons
(metrics-server + Cluster Autoscaler, both idempotent `kubectl apply`) → Deploy app + HPA +
PDB → Verify scaling config.** Re-running the pipeline is safe — it doesn't recreate
add-ons that are already healthy, it just reconciles them.

## 6. Load test to prove it scales
```bash
kubectl run load-generator --rm -i --tty --restart=Never --image=busybox -- \
  /bin/sh -c "while true; do wget -q -O- http://ha-app-svc.ha-app.svc.cluster.local/cpu-work; done"

watch kubectl get hpa ha-app-hpa -n ha-app
watch kubectl get nodes
```
Expect: HPA replica count climbs toward `maxReplicas: 20` as CPU utilization crosses 60%; once
existing nodes are full, `kubectl get pods -n ha-app` will show some `Pending`, and within a
few minutes the node count grows (Cluster Autoscaler adding capacity) and those pods schedule.

**[Screenshot placeholder: `kubectl get hpa` showing replicas climbing under load]**
**[Screenshot placeholder: `kubectl get nodes` before and after Cluster Autoscaler adds a node]**
**[Screenshot placeholder: Jenkins pipeline, "Verify scaling config" stage output]**
**[Screenshot placeholder: AWS console — EC2 Auto Scaling Group desired count increasing]**

## Resource efficiency & reliability notes
- Every container has both `requests` and `limits` set — HPA math is meaningless without
  `requests`, and `limits` stop one noisy pod from starving others on a shared node.
- `PodDisruptionBudget` (`minAvailable: 2`) keeps Cluster Autoscaler / node-drain operations
  from ever taking the app below 2 healthy replicas at once.
- `topologySpreadConstraints` + pod anti-affinity spread replicas across AZs/nodes so a single
  AZ or node failure doesn't take down the whole app — this is the actual "High Availability"
  part, independent of autoscaling.
- HPA `scaleDown.stabilizationWindowSeconds: 300` avoids flapping (rapid scale up/down) from
  brief traffic spikes, while `scaleUp` reacts within 30s.

## Cleanup
```bash
kubectl delete -f k8s/
cd terraform && terraform destroy
```
