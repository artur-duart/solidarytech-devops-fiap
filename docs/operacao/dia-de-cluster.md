# Roteiro do dia de cluster

Sequência para subir o ambiente, validar e encerrar no mesmo dia. As stacks `bootstrap` e `persistent` ficam sempre de pé; só a `main` sobe e desce.

## 1. Subir a infraestrutura (cerca de 20 minutos)

```bash
terraform -chdir=infra/main init
terraform -chdir=infra/main apply
```

No primeiro `apply` de um cluster novo, os recursos que falam com o Kubernetes podem falhar com `namespaces is forbidden` ou `Kubernetes cluster unreachable`, porque a permissão de acesso ao EKS leva alguns segundos para propagar. Basta rodar o `apply` de novo.

## 2. Bootstrap

```bash
bash scripts/bootstrap-cluster.sh
```

Cria os Secrets dos bancos a partir do Secrets Manager e entrega as Applications ao ArgoCD. Os Jobs de schema rodam sozinhos antes do primeiro sync.

## 3. Validar

```bash
kubectl get applications -n argocd
kubectl get pods -n solidarytech
ALB=$(kubectl get ingress solidarytech -n solidarytech -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -s "http://$ALB/ngos"
curl -s -X POST "http://$ALB/donations" -H 'Content-Type: application/json' -d '{"ngo_id":1,"amount":25,"donor_name":"Teste"}'
curl -s -X POST "http://$ALB/volunteers" -H 'Content-Type: application/json' -d '{"name":"Teste","email":"teste@exemplo.org","ngo_id":1}'
python scripts/auditar-tags.py
```

O ALB leva de dois a três minutos para responder depois de criado. A auditoria deve terminar com cobertura de tags de 100%.

## 4. Encerrar (obrigatório no mesmo dia)

```bash
bash scripts/encerrar-ambiente.sh
```

O script remove o Ingress, espera o controlador apagar o ALB e só então roda o `terraform destroy`. Destruir direto deixaria o ALB órfão, cobrando por hora e impedindo a remoção da VPC.
