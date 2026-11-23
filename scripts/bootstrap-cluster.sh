#!/usr/bin/env bash
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
CLUSTER="${EKS_CLUSTER:-solidarytech}"
NAMESPACE="solidarytech"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

step() { printf '\n\033[1;35m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die()  { printf '\n\033[1;31mERRO: %s\033[0m\n' "$*" >&2; exit 1; }

PY="$(command -v python || command -v python3 || true)"
[ -n "$PY" ] || die "python nao encontrado no PATH."
for bin in aws kubectl; do
  command -v "$bin" >/dev/null || die "$bin nao encontrado no PATH."
done

urlencode() { "$PY" -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1],safe=""))' "$1"; }
jqpy()      { "$PY" -c 'import sys,json;d=json.load(sys.stdin);exec("v=d"+sys.argv[1]);print(v)' "$1"; }
apply_secret() { kubectl create secret generic "$1" -n "$2" "${@:3}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null; info "secret $1 (ns $2)"; }

step "1/4 Apontando o kubectl para o cluster"
aws eks describe-cluster --name "$CLUSTER" --region "$REGION" >/dev/null 2>&1 \
  || die "cluster $CLUSTER nao existe em $REGION. Rode 'terraform -chdir=infra/main apply' antes."
aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" >/dev/null
kubectl get nodes >/dev/null || die "kubectl nao conseguiu falar com o cluster."
info "$(kubectl get nodes --no-headers | wc -l) no(s) prontos"

step "2/4 Conferindo o namespace e as service accounts criados pelo Terraform"
kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || die "namespace $NAMESPACE nao existe. O apply do Terraform terminou?"
for sa in donation-sa volunteer-sa; do
  kubectl get serviceaccount "$sa" -n "$NAMESPACE" >/dev/null 2>&1 || die "service account $sa nao existe."
  info "service account $sa"
done

step "3/4 Criando os Secrets dos bancos a partir do RDS e do Secrets Manager"
for svc in ngo donation; do
  DB_JSON="$(aws rds describe-db-instances --db-instance-identifier "solidarytech-$svc" --region "$REGION")"
  HOST="$(printf '%s' "$DB_JSON" | jqpy '["DBInstances"][0]["Endpoint"]["Address"]')"
  PORT="$(printf '%s' "$DB_JSON" | jqpy '["DBInstances"][0]["Endpoint"]["Port"]')"
  DBNM="$(printf '%s' "$DB_JSON" | jqpy '["DBInstances"][0]["DBName"]')"
  USER="$(printf '%s' "$DB_JSON" | jqpy '["DBInstances"][0]["MasterUsername"]')"
  ARN="$(printf '%s' "$DB_JSON" | jqpy '["DBInstances"][0]["MasterUserSecret"]["SecretArn"]')"
  PASS="$(aws secretsmanager get-secret-value --secret-id "$ARN" --region "$REGION" \
            --query SecretString --output text | jqpy '["password"]')"
  DSN="postgres://${USER}:$(urlencode "$PASS")@${HOST}:${PORT}/${DBNM}?sslmode=require"
  apply_secret "${svc}-secret" "$NAMESPACE" --from-literal=DATABASE_URL="$DSN"
done

step "4/4 Aplicando as Applications do ArgoCD"
if kubectl get crd applications.argoproj.io >/dev/null 2>&1; then
  kubectl apply -f "$REPO_ROOT/gitops/apps/" >/dev/null
  info "$(ls -1 "$REPO_ROOT/gitops/apps/" | wc -l) Applications aplicadas"
else
  info "CRD do ArgoCD ausente; o Terraform ainda esta instalando o ArgoCD."
  info "Rode novamente este script daqui a alguns minutos, ou so o passo:"
  info "  kubectl apply -f gitops/apps/"
fi

printf '\n\033[1;32mBootstrap concluido.\033[0m\n\n'
cat <<'EOF'
Verificacao:
  kubectl get applications -n argocd
  kubectl get pods -n solidarytech
  kubectl get ingress -n solidarytech
EOF
