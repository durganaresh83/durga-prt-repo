# Task 2 — Blue-Green Deployment on EKS with Jenkins + Helm

## Structure
```
task2-bluegreen-node/
├── terraform/     # EKS + ECR for the Node app
├── app/           # Node.js app + Dockerfile
├── helm/nodeapp/  # Helm chart parameterized by "color" (blue/green)
└── Jenkinsfile
```

## How Blue-Green works here
The chart deploys **two independent Deployments** (`nodeapp-blue`, `nodeapp-green`), each with
its own static ClusterIP Service for direct smoke-testing. A third Service,
`nodeapp-active-svc`, is the only one users actually hit (it's the `LoadBalancer`) — its
selector's `color` label is the single switch that decides who gets live traffic.

```
              ┌────────────────────┐
   users ───▶ │ nodeapp-active-svc │──▶ selector: color=blue   ──▶ nodeapp-blue pods (live)
              │  (LoadBalancer)    │        nodeapp-green pods (idle, being tested)
              └────────────────────┘
```

Cutover is just a `helm upgrade --set activeColor=green` — a label selector swap, not a pod
restart, so it's near-instant.

## 1. Provision infrastructure
This project uses the existing EKS cluster `durga-prt-flask-eks-demo` in `us-east-1` and the
ECR repository `durga-prt-flask-eks-demo-app`. The Terraform in this folder is kept minimal
and only reads those existing resources (it does not create a new cluster).

```bash
cd terraform
terraform init
# (terraform will read the existing EKS and ECR via data sources)
aws eks update-kubeconfig --region us-east-1 --name durga-prt-flask-eks-demo
helm version   # confirm helm CLI available on the Jenkins agent / your machine
```

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

## 3. Jenkins pipeline (parameterized)
Run with parameters:
- `TARGET_COLOR` = whichever color is currently **idle** (start with `green` if blue is live).
- `SWITCH_TRAFFIC` = `false` for a "deploy and test only" run, `true` to also cut traffic over.

Stages: **Checkout → Install & Test → Build & Push Image → Deploy to idle color → Smoke test
idle color → Switch traffic (only if `SWITCH_TRAFFIC=true`)**.

The pipeline never touches the currently-active color's Deployment until the explicit cutover
stage, so a failed build or failed smoke test leaves production completely untouched.

Recommended flow:
1. Run pipeline with `TARGET_COLOR=green`, `SWITCH_TRAFFIC=false` → deploys + smoke-tests green
   in isolation while blue keeps serving users.
2. Manually verify green (`kubectl port-forward svc/nodeapp-green-svc -n nodeapp 8080:80`),
   or add further automated tests.
3. Re-run (or resume) with `SWITCH_TRAFFIC=true` → `nodeapp-active-svc` selector flips to green.

## 4. Rollback strategy
Because the old color's pods are **never deleted** during cutover, rollback is just flipping
the selector back — no rebuild, no redeploy, no image pull:
```bash
helm upgrade nodeapp-blue helm/nodeapp \
  -f helm/nodeapp/values-blue.yaml \
  --namespace nodeapp \
  --set image.repository=<ECR_REPO_URL> \
  --set image.tag=<PREVIOUS_KNOWN_GOOD_TAG> \
  --set activeColor=blue
```
This takes effect in seconds since it's only a Service selector change. Options for triggering it:
- **Manual**: re-run the Jenkins job with `TARGET_COLOR=blue`, `SWITCH_TRAFFIC=true`.
- **Automated**: add a post-cutover smoke-test/monitoring stage that runs `helm upgrade
  ... --set activeColor=<previous>` automatically if error-rate/latency alerts fire within
  an N-minute bake window.
- `helm rollback nodeapp-<color> <REVISION>` also works if you need to revert a chart/values
  change itself, not just the active-color switch.

Keep the idle color's old Deployment running (don't `helm uninstall` it) for at least one
release cycle so rollback stays instantaneous.

## 5. Verify
```bash
kubectl get pods -n nodeapp -L color
kubectl get svc nodeapp-active-svc -n nodeapp -o jsonpath='{.spec.selector.color}'
curl http://<ACTIVE-SVC-EXTERNAL-IP>/
```

**[Screenshot placeholder: Jenkins build with SWITCH_TRAFFIC=true, all stages green]**
**[Screenshot placeholder: `kubectl get pods -n nodeapp -L color` showing both blue and green running]**
**[Screenshot placeholder: `curl` response before and after cutover showing `color` field flip]**
**[Screenshot placeholder: Helm release history — `helm history nodeapp-blue`]**

## Cleanup
```bash
helm uninstall nodeapp-blue nodeapp-green -n nodeapp
cd terraform && terraform destroy
```
