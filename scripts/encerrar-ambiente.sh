#!/usr/bin/env bash
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
CLUSTER="${EKS_CLUSTER:-solidarytech}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

step() { printf '\n\033[1;35m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }

albs_do_cluster() {
  aws resourcegroupstaggingapi get-resources --region "$REGION" \
    --resource-type-filters elasticloadbalancing:loadbalancer \
    --tag-filters "Key=elbv2.k8s.aws/cluster,Values=$CLUSTER" \
    --query 'length(ResourceTagMappingList)' --output text
}

step "1/3 Removendo o Ingress para o controlador apagar o ALB"
if aws eks describe-cluster --name "$CLUSTER" --region "$REGION" >/dev/null 2>&1; then
  aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" >/dev/null
  kubectl delete application ingress -n argocd --ignore-not-found >/dev/null
  kubectl delete ingress --all -n solidarytech --ignore-not-found --wait=true >/dev/null
  info "Ingress removido"
else
  info "cluster $CLUSTER nao existe; pulando"
fi

step "2/3 Esperando o ALB sumir da conta"
for _ in $(seq 1 30); do
  restantes="$(albs_do_cluster)"
  [ "$restantes" = "0" ] && break
  info "ALB ainda existe ($restantes), aguardando..."
  sleep 10
done
[ "$(albs_do_cluster)" = "0" ] && info "nenhum ALB do cluster restante" \
  || info "ATENCAO: ainda ha ALB do cluster. Confira no console antes de seguir."

step "3/3 Destruindo a stack principal"
terraform -chdir="$REPO_ROOT/infra/main" destroy
