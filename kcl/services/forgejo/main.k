deploy_workflow = """
name: Deploy Catalog

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: self-hosted
    steps:
      - name: Checkout repository
        run: |
          git init .
          git remote add origin \u0024GITHUB_SERVER_URL/\u0024GITHUB_REPOSITORY
          git fetch origin \u0024GITHUB_SHA
          git checkout \u0024GITHUB_SHA
      - name: Install kubectl
        run: |
          curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
          install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
      - name: Write kubeconfig
        env:
          KUBECONFIG_CONTENT: \u0024{{ secrets.KUBECONFIG_CONTENT }}
        run: |
          if [ -z "\u0024KUBECONFIG_CONTENT" ]; then echo "Missing KUBECONFIG_CONTENT"; exit 1; fi
          echo "\u0024KUBECONFIG_CONTENT" | base64 -d > kubeconfig
          echo "KUBECONFIG=\u0024PWD/kubeconfig" >> \u0024GITHUB_ENV
      - name: Configure Argo CD Forgejo repo access
        run: |
          cat <<'EOF' | kubectl apply -f -
          apiVersion: v1
          kind: Secret
          metadata:
            name: forgejo-repo
            namespace: argocd
            labels:
              argocd.argoproj.io/secret-type: repository
          stringData:
            url: http://172.18.0.1:3000/gitadmin/kind-dev
            username: gitadmin
            password: admin123
            insecure: "true"
          EOF
      - name: Bootstrap Argo CD
        run: |
          kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
          kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
          kubectl wait --for=condition=Available -n argocd deployment/argocd-server --timeout=300s
          kubectl apply -f argocd/root-app.yaml
"""

workflow = {
    "deploy.yml" = deploy_workflow
}
