# Estratégia de Tags (FinOps · Fase Informar)

Na nuvem, ninguém economiza o que não consegue ver. Para que cada real gasto pela SolidaryTech tenha um dono e um propósito, todos os recursos carregam um conjunto fixo de tags, aplicado por código desde o momento da criação. Este documento define essas tags, explica como elas são aplicadas e fiscalizadas, e registra o que ainda não pode ser alocado diretamente.

## Dicionário de tags

| Tag | Valores permitidos | Obrigatória | Para que serve |
|---|---|---|---|
| `Project` | `SolidaryTech` | sim | separar o custo da plataforma de qualquer outro projeto da conta |
| `Environment` | `Production`, `Staging`, `Development` | sim | distinguir o custo de produção do custo de testes |
| `CostCenter` | `NGO-<Area>`, hoje `NGO-Core` | sim | indicar qual orçamento da ONG paga o recurso (base do showback) |
| `Owner` | usuário responsável, hoje `artur-duart` | sim | saber a quem perguntar antes de alterar ou desligar um recurso |
| `ManagedBy` | `Terraform` | sim | sinalizar que o recurso não deve ser alterado pelo console |
| `Stack` | `bootstrap`, `persistent`, `main`, `dr` | sim | identificar qual stack do Terraform criou o recurso e o seu ciclo de vida |
| `Service` | `ngo-service`, `donation-service`, `volunteer-service` | quando o recurso pertence a um único serviço | atribuir custo a cada microsserviço, como o banco do donation-service |

## Como as tags são aplicadas

1. **Fonte única da verdade.** O módulo [`infra/modules/finops-tags`](../../infra/modules/finops-tags) define as tags e valida os valores. Um `Environment` ou `CostCenter` fora do padrão interrompe o `terraform plan`, então um recurso com tag errada nunca chega a ser criado.
2. **Herança automática.** Todas as stacks entregam as tags do módulo ao `default_tags` do provider AWS. Cada recurso criado pelo Terraform recebe as tags obrigatórias sem que ninguém precise lembrar de escrevê-las.
3. **Tag por recurso.** A tag `Service` é adicionada apenas nos recursos que pertencem a um serviço específico, como os repositórios de imagem e, mais adiante, os bancos de dados.
4. **Propagação para o que o Terraform não cria diretamente.** O `default_tags` não alcança recursos criados por outros sistemas em nome do Terraform. Esses três casos recebem as tags por outros caminhos:
   - instâncias EC2 dos nós do Kubernetes, criadas pelo Auto Scaling: tags no launch template do node group;
   - volumes EBS criados pelo Kubernetes: configuração de tags extras do driver EBS CSI;
   - load balancer criado pelo Ingress: anotação `aws-load-balancer-additional-resource-tags`, que o módulo já entrega pronta no output `kubernetes_annotation`.
5. **Ativação no faturamento.** Uma tag só aparece no Cost Explorer depois de ativada como *cost allocation tag*. A ativação também é feita por Terraform, na stack `persistent`, para todas as chaves do dicionário.
6. **Fiscalização contínua.** O pipeline de infraestrutura passa a reprovar mudanças que criem recursos sem as tags obrigatórias.

## Custos que não aceitam tag

Nem todo custo da nuvem pode ser marcado. Transferência de dados, o NAT Gateway compartilhado e o plano de controle do EKS servem aos três serviços ao mesmo tempo. Para esses custos compartilhados, a SolidaryTech adota a **alocação proporcional**: cada serviço absorve uma parte do custo comum na mesma proporção da CPU que reserva no cluster. Assim, o serviço que mais consome também carrega a maior fatia da infraestrutura comum, e nenhum custo fica sem dono.

## Nível de maturidade

Pelo modelo de maturidade da FinOps Foundation, a prática começa no estágio **Engatinhar** e já atende a critérios do estágio **Andar**: as tags são aplicadas automaticamente por código desde a criação de cada recurso, e os custos de produção podem ser alocados por projeto, ambiente, centro de custo e serviço. A meta para os próximos ciclos é alocar mais de 80% do gasto mensal diretamente a um serviço, reduzindo a fatia distribuída por proporção.
