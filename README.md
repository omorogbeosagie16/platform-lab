# platform-lab

A small Platform-as-Code project on AWS. Everything is defined as code in this repository and is meant to be created, changed and destroyed from it.

| Layer | Tool | What it does |
|---|---|---|
| Infrastructure | Terraform | VPC, security groups and EC2 servers from a reusable module, with remote, locked state |
| Images | Packer | Bakes a patched, hardened Ubuntu AMI using the same Ansible roles |
| Configuration | Ansible | Configures and hardens Linux hosts found through a dynamic AWS inventory |
| Orchestration | Jenkins | Pipeline as code: lint, plan, approval, apply, configure |
| Containers | Docker, k3s | A small containerised app, run with Compose and on a single-node Kubernetes cluster |
| Quality gates | pre-commit | Formatting, lint and secret scanning before every commit |

This is a learning lab, not a production system. See [Status](#status) for what was exercised and what was only written.

## How the pieces fit together

```
Git pull request  (pre-commit: terraform fmt/validate/tflint, ansible-lint, gitleaks)
        |
        v  merge to main
Jenkins pipeline:  lint -> terraform plan -> manual approval -> apply -> ansible
        |
        v
AWS:  VPC, subnet, security group, EC2 servers
        ^                         ^
        |                         |
Terraform finds the golden AMI    Ansible configures hosts by tag (role_web, env_dev, ...)
by tag                            using the same roles Packer uses to build the image
```

## Repository layout

```
.
├── Jenkinsfile                 Pipeline: lint, plan, approve, apply, configure
├── .pre-commit-config.yaml     Local quality gates
├── .ansible-lint               Lint rules for the Ansible code
├── terraform/
│   ├── bootstrap/              One-time setup: S3 state bucket, GitHub OIDC provider, IAM roles (local state)
│   ├── modules/platform/       Reusable module: VPC, subnet, security group, key pair, EC2 servers
│   ├── envs/dev/               Environment wrapper around the module (backend.hcl + dev.tfvars.example)
│   ├── envs/uat/               Second environment using the same module
│   └── tooling/                The Jenkins server (own state file)
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/aws_ec2.yml   Dynamic inventory: groups built from EC2 tags
│   ├── requirements.yml        Ansible collections
│   ├── playbooks/              site.yml, golden.yml, k3s.yml, jenkins.yml
│   └── roles/                  common, hardening, k3s, jenkins, cicd_tools
├── packer/ubuntu.pkr.hcl       Golden Ubuntu 24.04 AMI
├── app/                        Small Flask app, Dockerfile and docker-compose.yml
└── k8s/app.yaml                Kubernetes manifests for the app
```

## Prerequisites

- An AWS account and credentials for the first (bootstrap) run. Afterwards the tools can use an instance role or OIDC, so no long-lived keys are needed.
- Terraform 1.10 or later, Packer, Ansible (with `boto3`), Docker, `kubectl`.
- `pre-commit` (optional but recommended): `pre-commit install`.

## Getting started

Region and names below are examples; adjust them to your account.

**1. Bootstrap the remote state (once, local state)**

```bash
cd terraform/bootstrap
terraform init
terraform apply          # asks for github_repo as owner/repo
```

**2. Create an environment**

```bash
cd terraform/envs/dev
cp dev.tfvars.example dev.tfvars        # real values; this file is gitignored
# edit backend.hcl so the bucket name matches the state bucket from step 1
terraform init -backend-config=backend.hcl
terraform plan  -var-file=dev.tfvars -out=tfplan
terraform apply tfplan
```

**3. Configure the servers**

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-inventory --graph               # servers appear grouped by tag
ansible-playbook playbooks/site.yml --check --diff
ansible-playbook playbooks/site.yml
```

A second run should report `changed=0`.

**4. Build a golden image (optional)**

```bash
cd packer
packer init . && packer validate . && packer build .
```

Servers with `os = "golden"` in `dev.tfvars` launch from the newest AMI tagged `Role=golden`.

**5. Run the containerised app**

```bash
cd app
docker compose up -d --build
curl localhost:8080 ; curl localhost:8080/health
```

**6. Kubernetes (k3s)**

Add a server with `role = "k8s"` (for example a `t3.medium`) to `dev.tfvars` and apply, then:

```bash
cd ansible
ansible-playbook playbooks/k3s.yml
# fetch the kubeconfig and point it at the server's public IP (keep it out of Git)
ansible role_k8s -b -m fetch -a "src=/etc/rancher/k3s/k3s.yaml dest=$HOME/.kube/k3s.yaml flat=yes"
export KUBECONFIG=$HOME/.kube/k3s.yaml
# make the image available to the node (registry push, or docker save + k3s ctr images import),
# then deploy with the server IP substituted into the placeholder:
sed "s/__K3S_IP__/<server public ip>/" k8s/app.yaml | kubectl apply -f -
kubectl -n app get all,ingress
```

**7. Tear down**

Destroy each environment with `terraform destroy` (dev, tooling, then bootstrap last), and delete any AMIs and snapshots Packer created. AMI snapshots keep billing until removed.

## Design notes

- **Remote state, one per environment.** The backend block is empty (`backend "s3" {}`) and `backend.hcl` supplies the bucket and key at `init`, so the same code serves every environment with its own state file and native S3 locking.
- **No stored cloud keys.** Servers and Jenkins use instance roles; the bootstrap also creates a GitHub OIDC role for CI.
- **Secrets stay out of Git.** Real `*.tfvars` files are gitignored (a `.example` file is committed), and `gitleaks` runs as a pre-commit hook. Jenkins receives the real tfvars and the SSH key as credentials.
- **Roles are the single source of truth.** The same Ansible roles configure live servers and build the golden image.
- **Idempotent automation.** Roles use modules that report `changed=0` on a second run; `command` tasks are guarded with `creates` or `changed_when`.
- **Safe SSH changes.** The hardening role installs a validated sshd drop-in (`sshd -t`) and restarts sshd only through a handler when it changes.
- **Placeholders for addresses.** The Kubernetes manifest uses `__K3S_IP__` so no real IP is committed.

## Status

| Component | State |
|---|---|
| Terraform bootstrap, `modules/platform`, `envs/dev`, `tooling` | Applied and destroyed in an AWS lab |
| `envs/uat` | Planned only, never applied |
| Ansible `common`, `hardening`, `k3s` roles | Run against Ubuntu and Rocky Linux hosts; second runs were idempotent |
| Ansible `jenkins`, `cicd_tools` roles | Written and lint-clean; not run against a live server (the lab's Jenkins was installed with a shell script) |
| Packer golden image | Built, launched through Terraform and verified |
| `Jenkinsfile` | Ran end to end (lint, plan, approval, apply, configure) |
| `app/` and `k8s/app.yaml` | Built and run with Compose, deployed on k3s, including a rolling update and rollback |
| Helm chart, container registry push | Not included |

## Cost and safety

Resources are small (`t3.micro` and `t3.medium`) but they do bill while running. Always check `terraform plan -destroy` before destroying, and verify afterwards that no instances, volumes, AMIs or snapshots remain.
