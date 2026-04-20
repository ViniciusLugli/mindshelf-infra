# Mindshelf Infra

Infraestrutura como codigo em Terraform para publicar a aplicacao Mindshelf na AWS com foco em uma arquitetura simples, mas pronta para evoluir.

O projeto provisiona rede, balanceamento, containers, banco de dados, DNS, certificado TLS e repositorios de imagem para rodar frontend e backend em ECS Fargate.

## Visao geral

Esta stack cria os seguintes componentes na AWS:

- **VPC** com 2 subnets publicas, 2 subnets privadas e NAT Gateway.
- **Application Load Balancer (ALB)** com HTTP redirecionando para HTTPS.
- **Roteamento por caminho**: frontend como rota padrao e backend atendendo `/api/*`.
- **ECS Fargate** para frontend e backend, cada um com task definition e service proprios.
- **Amazon ECR** para armazenar as imagens Docker do frontend e do backend.
- **Amazon RDS PostgreSQL** em subnets privadas.
- **AWS Systems Manager Parameter Store** para segredos e strings de conexao.
- **Route 53** para zona hospedada e registros DNS.
- **AWS Certificate Manager (ACM)** para certificado TLS com validacao via DNS.
- **CloudWatch Logs** para logs dos containers.

## Arquitetura

```text
Internet
  |
  v
Route 53 -> ACM
  |
  v
Application Load Balancer
  |-- /           -> frontend (ECS Fargate)
  `-- /api/*      -> backend  (ECS Fargate)
                        |
                        v
                  SSM Parameter Store
                        |
                        v
                   RDS PostgreSQL

Build/deploy pipeline
  |
  v
Amazon ECR (frontend/backend images)
```

## O que cada arquivo faz

- `main.tf`: versao minima do Terraform e provider AWS.
- `variables.tf`: variaveis de configuracao da stack.
- `vpc.tf`: cria a VPC e suas subnets usando o modulo oficial `terraform-aws-modules/vpc/aws`.
- `alb.tf`: security groups, ALB, listeners e target groups.
- `ecr.tf`: repositorios ECR para frontend e backend.
- `ecs.tf`: cluster ECS, task definitions, services e grupos de log.
- `rds.tf`: banco PostgreSQL, subnet group, senha gerada e parametros no SSM.
- `iam.tf`: roles e policies usadas pelas tasks do ECS.
- `route53.tf`: hosted zone, certificado ACM e registros DNS.
- `output.tf`: saidas uteis do deploy.
- `terraform.tfvars`: valores locais da sua implantacao. Este arquivo esta no `.gitignore`.

## Recursos provisionados em detalhes

### Rede

O projeto cria uma VPC com CIDR `10.0.0.0/16`, duas zonas de disponibilidade e a separacao abaixo:

- `10.0.1.0/24` e `10.0.2.0/24`: subnets publicas.
- `10.0.3.0/24` e `10.0.4.0/24`: subnets privadas.
- `single_nat_gateway = true`: apenas um NAT Gateway para reduzir custo.

Isso permite que o ALB fique exposto publicamente e que ECS/RDS permaneçam em subnets privadas.

### Balanceamento e roteamento

O ALB recebe trafego HTTP e HTTPS:

- Porta `80`: redireciona para HTTPS.
- Porta `443`: termina TLS com certificado do ACM.
- Rota padrao: frontend.
- Regra `/api/*`: encaminha para o backend.

Health checks configurados:

- Backend: `GET /health`
- Frontend: `GET /`

### Containers e aplicacao

O ECS usa Fargate para evitar administracao de instancias EC2.

- **Backend**
  - Porta esperada: `8080`
  - Variaveis de ambiente: `NODE_ENV`, `LOG_LEVEL`, `ALLOWED_ORIGINS`
  - Segredos vindos do SSM: `DATABASE_URL`, `DSN`, `JWT_SECRET`

- **Frontend**
  - Porta esperada: `3000`
  - Variaveis de ambiente: `API_PROXY_TARGET`, `NEXT_PUBLIC_WS_PATH`

### Banco de dados

O RDS PostgreSQL e criado com:

- armazenamento criptografado
- acesso privado apenas a partir do security group do ECS
- senha gerada automaticamente via `random_password`
- parametros de conexao publicados no SSM

### DNS e certificado

Ao aplicar a stack, o Terraform:

- cria uma hosted zone no Route 53 para o dominio informado
- emite um certificado ACM para o dominio raiz e wildcard `*.dominio`
- cria os registros de validacao automaticamente
- cria registros `A` para o dominio raiz e `www`

Importante: depois do primeiro `apply`, voce ainda precisa apontar o dominio no seu registrador para os nameservers retornados em `route53_nameservers`.

## Pre-requisitos

Antes de usar este projeto, garanta que voce tem:

- conta AWS com permissoes para VPC, ECS, ECR, IAM, RDS, Route 53, ACM, SSM e CloudWatch
- Terraform `>= 1.5`
- AWS CLI configurada com credenciais validas
- Docker instalado, caso voce va buildar e enviar imagens para o ECR
- um dominio que possa ser delegado para o Route 53

Exemplo rapido para validar credenciais:

```bash
aws sts get-caller-identity
terraform version
```

## Variaveis de entrada

### Obrigatorias

Estas variaveis devem ser definidas no `terraform.tfvars` ou por `-var`:

| Variavel             | Descricao                                                  |
| -------------------- | ---------------------------------------------------------- |
| `domain_name`        | Dominio principal da aplicacao, por exemplo `meusite.com`. |
| `backend_jwt_secret` | Segredo JWT usado pelo backend.                            |

### Opcionais importantes

| Variavel                     | Padrao         | Descricao                                                                              |
| ---------------------------- | -------------- | -------------------------------------------------------------------------------------- |
| `aws_region`                 | `us-east-1`    | Regiao AWS usada no deploy.                                                            |
| `project_name`               | `meu-projeto`  | Prefixo usado nos nomes dos recursos.                                                  |
| `backend_image`              | `nginx:latest` | Imagem do backend. Deve ser substituida por uma imagem real antes do deploy completo.  |
| `frontend_image`             | `nginx:latest` | Imagem do frontend. Deve ser substituida por uma imagem real antes do deploy completo. |
| `backend_port`               | `8080`         | Porta publicada pelo backend.                                                          |
| `frontend_port`              | `3000`         | Porta publicada pelo frontend.                                                         |
| `backend_task_cpu`           | `512`          | CPU da task do backend no Fargate.                                                     |
| `backend_task_memory`        | `1024`         | Memoria da task do backend em MiB.                                                     |
| `backend_desired_count`      | `1`            | Quantidade desejada de tasks do backend.                                               |
| `frontend_task_cpu`          | `256`          | CPU da task do frontend no Fargate.                                                    |
| `frontend_task_memory`       | `512`          | Memoria da task do frontend em MiB.                                                    |
| `frontend_desired_count`     | `1`            | Quantidade desejada de tasks do frontend.                                              |
| `backend_log_level`          | `info`         | Nivel de log do backend.                                                               |
| `backend_allowed_origins`    | `null`         | Origem de CORS; se nao for definida, usa `https://<domain_name>`.                      |
| `db_name`                    | `project`      | Nome do banco PostgreSQL.                                                              |
| `db_username`                | `project`      | Usuario administrador da base.                                                         |
| `db_instance_class`          | `db.t4g.micro` | Tipo da instancia do RDS.                                                              |
| `db_engine_version`          | `16.3`         | Versao do PostgreSQL.                                                                  |
| `db_allocated_storage`       | `20`           | Armazenamento inicial em GB.                                                           |
| `db_max_allocated_storage`   | `100`          | Limite maximo de auto scaling de storage.                                              |
| `db_multi_az`                | `false`        | Ativa alta disponibilidade no banco.                                                   |
| `db_backup_retention_period` | `7`            | Dias de retencao de backup.                                                            |
| `db_deletion_protection`     | `false`        | Impede remocao acidental do banco.                                                     |
| `db_skip_final_snapshot`     | `true`         | Pula snapshot final ao destruir o banco.                                               |

## Exemplo de `terraform.tfvars`

Nao versione este arquivo com valores reais.

```hcl
aws_region              = "us-east-1"
project_name            = "project"
domain_name             = "seudominio.com"

backend_image           = "<aws-account-id>.dkr.ecr.us-east-1.amazonaws.com/project-backend:latest"
frontend_image          = "<aws-account-id>.dkr.ecr.us-east-1.amazonaws.com/project-frontend:latest"

backend_port            = 8080
frontend_port           = 3000

backend_jwt_secret      = "troque-por-um-segredo-forte"
backend_log_level       = "info"
backend_allowed_origins = "https://seudominio.com"

db_name                 = "project"
db_username             = "project"
db_instance_class       = "db.t4g.micro"
db_engine_version       = "16.3"
db_allocated_storage    = 20
db_max_allocated_storage = 100
db_multi_az             = false
db_backup_retention_period = 7
db_deletion_protection  = false
db_skip_final_snapshot  = true
```

## Como fazer o primeiro deploy

### Opcao recomendada: bootstrap em duas etapas

Como os repositorios ECR sao criados pelo proprio Terraform, o fluxo mais seguro e:

1. Criar apenas os repositorios ECR.
2. Buildar e enviar as imagens reais.
3. Executar o deploy completo.

#### 1) Inicializar o Terraform

```bash
terraform init
```

#### 2) Criar somente os repositorios ECR

```bash
terraform apply \
  -target=aws_ecr_repository.backend \
  -target=aws_ecr_repository.frontend
```

#### 3) Obter as URLs dos repositorios ECR

```bash
terraform output -raw ecr_backend_url
terraform output -raw ecr_frontend_url
```

#### 4) Autenticar no ECR

```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <aws-account-id>.dkr.ecr.us-east-1.amazonaws.com
```

Substitua `us-east-1` e `<aws-account-id>` pelos valores da sua conta.

#### 5) Buildar e enviar imagens

```bash
docker build -t project-backend <caminho-do-backend>
docker tag project-backend:latest <ecr_backend_url>:latest
docker push <ecr_backend_url>:latest

docker build -t project-frontend <caminho-do-frontend>
docker tag project-frontend:latest <ecr_frontend_url>:latest
docker push <ecr_frontend_url>:latest
```

Substitua `<caminho-do-backend>` e `<caminho-do-frontend>` pelos diretorios reais onde vivem as aplicacoes.

#### 6) Atualizar o `terraform.tfvars`

Preencha `backend_image` e `frontend_image` com as URLs finais do ECR.

#### 7) Validar o plano

```bash
terraform plan
```

#### 8) Aplicar a stack completa

```bash
terraform apply
```

#### 9) Delegar o dominio no registrador

Depois do `apply`, pegue os nameservers:

```bash
terraform output route53_nameservers
```

Configure esses nameservers no registrador do seu dominio. So depois disso o certificado e a resolucao DNS vao funcionar completamente para trafego externo.

## Comandos uteis do dia a dia

```bash
terraform fmt
terraform validate
terraform plan
terraform apply
terraform destroy
```

Ver outputs:

```bash
terraform output
terraform output site_url
terraform output ecr_backend_url
terraform output ecr_frontend_url
```

## Outputs disponiveis

| Output                       | Descricao                                              |
| ---------------------------- | ------------------------------------------------------ |
| `alb_dns`                    | DNS publico do Application Load Balancer.              |
| `site_url`                   | URL principal da aplicacao (`https://<domain_name>`).  |
| `ecr_backend_url`            | URL do repositorio ECR do backend.                     |
| `ecr_frontend_url`           | URL do repositorio ECR do frontend.                    |
| `route53_nameservers`        | Nameservers para configurar no registrador do dominio. |
| `postgres_endpoint`          | Endpoint do banco PostgreSQL.                          |
| `postgres_port`              | Porta do PostgreSQL.                                   |
| `database_url_ssm_parameter` | Nome do parametro SSM com a `DATABASE_URL`.            |
| `dsn_ssm_parameter`          | Nome do parametro SSM com a `DSN`.                     |

## Seguranca e operacao

- O banco nao fica publico e so aceita conexao a partir das tasks do ECS.
- Segredos sao armazenados no Parameter Store como `SecureString` quando aplicavel.
- O ECS recebe permissao para ler parametros do caminho `/${project_name}/backend/*`.
- O trafego publico entra apenas pelo ALB.
- Os logs de frontend e backend vao para CloudWatch Logs com retencao de 7 dias.

## Pontos de atencao

### 1. Imagens placeholder

Os valores padrao `nginx:latest` em `backend_image` e `frontend_image` servem apenas como placeholder. Eles **nao** combinam com as portas e health checks esperados por esta stack. Para um deploy funcional, use imagens reais da aplicacao.

### 2. Porta do backend

Em `ecs.tf`, o container do backend esta definido com `containerPort = 8080`. Se voce mudar `backend_port`, mantenha a task definition alinhada com a porta exposta pela aplicacao.

### 3. Estado remoto

Hoje o projeto nao define backend remoto do Terraform. Isso significa que o estado fica local por padrao. Para ambientes de time ou producao, o ideal e migrar o state para S3 com lock em DynamoDB.

### 4. Hosted zone nova

O Terraform cria uma hosted zone do zero. Se o dominio ja estiver sendo usado fora da AWS, planeje a migracao de DNS com cuidado antes de delegar os nameservers.

### 5. Custos

Mesmo em ambiente pequeno, alguns recursos geram custo continuo:

- NAT Gateway
- Application Load Balancer
- RDS PostgreSQL
- ECS Fargate
- armazenamento e trafego no ECR/CloudWatch

## Troubleshooting

### Certificado nao valida

- confirme se o dominio ja aponta para os nameservers do Route 53
- rode `terraform output route53_nameservers`
- verifique no ACM se os registros de validacao foram criados

### ECS service nao estabiliza

- confira se `backend_image` e `frontend_image` apontam para imagens validas
- valide se o frontend responde na porta `frontend_port`
- valide se o backend responde na porta `8080` e no endpoint `/health`
- veja logs no CloudWatch

### Backend nao conecta no banco

- confira se os parametros SSM foram criados
- revise as permissoes IAM da task
- valide se o banco terminou a criacao e esta `available`

### Site nao abre pelo dominio

- confira se o dominio foi delegado aos nameservers do Route 53
- teste primeiro o `alb_dns` para separar problema de DNS de problema da aplicacao

## Melhorias recomendadas

Se voce quiser evoluir esta stack, alguns proximos passos naturais sao:

- configurar backend remoto do Terraform em S3 + DynamoDB
- separar ambientes (`dev`, `staging`, `prod`) com workspaces ou diretorios dedicados
- usar Secrets Manager para segredos mais sensiveis e rotacao
- adicionar autoscaling para os services do ECS
- habilitar observabilidade mais completa com alarmes e dashboards
- colocar CI/CD para build, push e deploy automatizados

## Fluxo resumido de uso

```text
1. Configure credenciais AWS
2. Preencha terraform.tfvars
3. terraform init
4. Crie os repositorios ECR
5. Envie as imagens reais
6. terraform plan
7. terraform apply
8. Delegue o dominio para os nameservers do Route 53
9. Acesse o site em https://<domain_name>
```
