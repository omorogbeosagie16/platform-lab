pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    timeout(time: 45, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  parameters {
    choice(name: 'ACTION', choices: ['plan', 'apply'], description: 'plan = preview only; apply = approve, apply, then configure with Ansible')
  }

  environment {
    PATH               = "/opt/venv/ansible/bin:${env.PATH}"
    TF_IN_AUTOMATION   = 'true'
    TF_INPUT           = '0'
    TF_DIR             = 'terraform/envs/dev'
    AWS_DEFAULT_REGION = 'us-east-2' // credentials come from the instance role, nothing stored in Jenkins
  }

  stages {
    stage('Lint') {
      parallel {
        stage('Terraform fmt') {
          steps { sh 'terraform fmt -check -recursive terraform' }
        }
        stage('Ansible lint') {
          steps { sh 'ansible-lint' }
        }
      }
    }

    stage('Terraform Plan') {
      steps {
        withCredentials([
          string(credentialsId: 'dev-tfvars', variable: 'TFVARS'),
          sshUserPrivateKey(credentialsId: 'lab-ssh', keyFileVariable: 'SSH_KEY')
        ]) {
          dir(env.TF_DIR) {
            sh '''
              # The real tfvars is a secret held in Jenkins, not in Git.
              printf '%s\n' "$TFVARS" > dev.tfvars
              # Derive the public key from the private key so no extra file is needed.
              ssh-keygen -y -f "$SSH_KEY" > "$WORKSPACE/lab.pub"
              terraform init -backend-config=backend.hcl
              terraform validate
              terraform plan -var-file=dev.tfvars -var "ssh_public_key_path=$WORKSPACE/lab.pub" -out=tfplan
              terraform show -no-color tfplan > plan.txt
            '''
          }
        }
        archiveArtifacts artifacts: "${env.TF_DIR}/plan.txt"
      }
    }

    stage('Approve') {
      when { expression { params.ACTION == 'apply' } }
      steps {
        timeout(time: 30, unit: 'MINUTES') {
          input message: 'Apply this plan to dev?', ok: 'Proceed'
        }
      }
    }

    stage('Terraform Apply') {
      when { expression { params.ACTION == 'apply' } }
      steps {
        dir(env.TF_DIR) { sh 'terraform apply tfplan' }
      }
    }

    stage('Configure') {
      when { expression { params.ACTION == 'apply' } }
      steps {
        withCredentials([sshUserPrivateKey(credentialsId: 'lab-ssh', keyFileVariable: 'SSH_KEY')]) {
          dir('ansible') {
            sh 'ansible-playbook playbooks/site.yml --private-key "$SSH_KEY" --limit env_dev'
          }
        }
      }
    }
  }

  post {
    success { echo 'Pipeline finished OK' }
    failure { echo 'Pipeline failed, read the console log' }
    cleanup { cleanWs(deleteDirs: true, notFailBuild: true) }
  }
}
