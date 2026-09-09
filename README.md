# tech-challenge-kubernetes

Infraestrutura Terraform do cluster **AWS EKS** + rede (VPC, subnets,
security groups) e os manifests Kubernetes (`k8s/`) que fazem o deploy real
de produção da aplicação
[`tech-challenge-application`](https://github.com/eduNsantos/tech-challenge-application)
e do Swagger UI. É o **alvo de deploy real** do sistema POS — o `infra/` da
própria aplicação sobe apenas um Minikube local, para desenvolvimento local.

## Escopo

### Terraform (infraestrutura)

| Arquivo | Recurso |
| --- | --- |
| `vpc.tf` | VPC `main` + 2 subnets públicas (`sub_a`, `sub_b`) |
| `internet-gateway.tf` | Internet Gateway + rota pública |
| `security-groups.tf` | Security Groups `eks` (tráfego interno + portas 8080/8082 liberadas para IP fixo) e `rds` (o mesmo referenciado como `data source` por [`tech-challenge-database`](https://github.com/eduNsantos/tech-challenge-database)) |
| `eks.tf` | Cluster EKS 1.35 + node group (`t3.small`, 1–2 nós) + IAM roles/policies do cluster e dos nodes |

### Kubernetes (aplicação)

| Manifest | Função |
| --- | --- |
| `k8s/00-namespaces/namespace.yaml` | Namespace `postech` |
| `k8s/01-config/configmap.yaml` | Variáveis de ambiente da app Laravel (`DB_HOST` aponta para a RDS de `tech-challenge-database`) |
| `k8s/01-config/openapi-configmap.yaml` | ConfigMap com o `openapi.yaml` servido pelo Swagger UI |
| `k8s/01-config/secret.example.yaml` | Modelo do Secret `app-secret` (`APP_KEY`, `DB_PASSWORD`, `JWT_SECRET`, `MAIL_*`) — nunca commitar o real |
| `k8s/02-app/app-deployment.yaml` | Deployment da app Laravel (2 réplicas, probes em `/up`) |
| `k8s/02-app/app-service.yaml` | Service `LoadBalancer`, porta 8080 |
| `k8s/02-app/app-hpa.yaml` | HPA: 2–4 réplicas, alvo 70% de CPU |
| `k8s/02-app/migrate-job.yaml` | Job de `php artisan migrate`, rodado a cada deploy |
| `k8s/02-app/swagger-deployment.yaml` + `swagger-service.yaml` | Swagger UI servindo o `openapi.yaml` |

## CI/CD

`.github/workflows/deploy-eks.yml`, disparado por `repository_dispatch`
(evento `deploy-eks`) a partir do `build-ghcr.yml` de
`tech-challenge-application` — ou manualmente via `workflow_dispatch`. Cada
execução:

1. Configura o kubeconfig do cluster EKS.
2. Aplica o Secret de pull do GHCR e o ConfigMap.
3. Recria o Secret `app-secret` a partir dos secrets do repositório GitHub.
4. Roda o Job de migration (`migrate-job.yaml`) com a imagem nova e espera
   ele completar.
5. Atualiza a imagem do Deployment e faz o rollout.

### Secrets necessários no repositório

`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `GHCR_USERNAME`, `GHCR_TOKEN`,
`GHCR_EMAIL`, `APP_KEY`, `DB_PASSWORD`, `JWT_SECRET`, `MAIL_USERNAME`,
`MAIL_PASSWORD`.

## Rodar/aplicar localmente

```bash
# Infraestrutura (VPC + EKS)
terraform init
terraform plan
terraform apply

# Configura acesso ao cluster criado
aws eks update-kubeconfig --name main --region us-east-1

# Aplica os manifests, na ordem
kubectl apply -f k8s/00-namespaces/
kubectl apply -f k8s/01-config/configmap.yaml
kubectl create configmap openapi-spec --from-file=openapi.yaml -n postech

cp k8s/01-config/secret.example.yaml k8s/01-config/secret.yaml
# preencha secret.yaml com valores reais em base64 — nunca commitar
kubectl apply -f k8s/01-config/secret.yaml

kubectl apply -f k8s/02-app/
```

## Acesso

- Aplicação: porta `8080` do Service `postech-app` (`LoadBalancer`).
- Swagger UI: porta `8082`, servindo o `openapi.yaml` de
  `tech-challenge-application`.

## Repositórios relacionados

- [`tech-challenge-application`](https://github.com/eduNsantos/tech-challenge-application) — código da aplicação; dispara este deploy via CI.
- [`tech-challenge-database`](https://github.com/eduNsantos/tech-challenge-database) — RDS gerenciada; referencia via `data source` a VPC/Security Group criados aqui.
- [`tech-challenge-lambda-functions`](https://github.com/eduNsantos/tech-challenge-lambda-functions) — Function serverless de autenticação; também referencia a VPC criada aqui.
