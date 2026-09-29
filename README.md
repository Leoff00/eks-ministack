# Laboratório EKS local com Terraform e Ministack

Este laboratório parte do zero: cria rede e papéis IAM, declara um cluster EKS e um managed node group com Terraform e publica uma aplicação HTTP no Kubernetes. O único emulador de serviços AWS utilizado é o [Ministack](https://ministack.org/); para executar o Kubernetes ele inicia um **sidecar k3s real** pelo Docker do host.

> **Limite importante:** `aws_eks_node_group.workers` é uma representação da API de EKS. No Ministack ele **não cria uma instância EC2 nem um worker Kubernetes separado**. O Pod roda no nó k3s que `kubectl get nodes` mostrar (neste laboratório, o nó do control plane). As VPCs, subnets, rotas e políticas IAM também são emuladas: não fornecem uma rede VPC nem autorização AWS reais.

## Roteiro de estudo

| Etapa | O que fazer | O que observar |
| --- | --- | --- |
| 1. Endpoint local | Subir o Ministack e apontar Terraform/AWS CLI para `localhost:4566`. | Conta padrão `000000000000` com chave `test`, segredo `test`, região `us-east-1`. A expressão `test-test-us-east-1` junta esses três valores; **não é o nome de uma região**. |
| 2. Rede | Examinar `terraform/network.tf`: VPC, duas subnets em AZs diferentes, internet gateway, rota pública e associação. | Na AWS real, isso dá endereçamento e saída para nós públicos. Aqui é metadado EC2; o tráfego dos Pods passa pela rede Docker/k3s. |
| 3. Identidade | Examinar `terraform/iam.tf`: confiança `eks.amazonaws.com` para o cluster, `ec2.amazonaws.com` para os nós; anexos das políticas gerenciadas. | Distinguir papel do serviço EKS, papel dos nós e acesso de pessoas ao Kubernetes (access entries). Em produção, permissões de Pods devem ter identidade própria (EKS Pod Identity/IRSA), não usar indiscriminadamente o papel do nó. |
| 4. Control plane | Aplicar `aws_eks_cluster` com as subnets, acesso ao endpoint e versão Kubernetes. | `aws eks describe-cluster` mostra a API emulada; o endpoint HTTPS e o certificado apontam para o k3s efetivo. `aws eks update-kubeconfig` conecta o `kubectl`. |
| 5. Capacidade | Aplicar `aws_eks_node_group` com subnets, papel e limites de escala. | Comparar `aws eks describe-nodegroup` com `kubectl get nodes`: o primeiro confirma o cadastro EKS; **somente o segundo confirma nós utilizáveis para Pods**. |
| 6. Imagem e workload | Criar o repositório ECR via Terraform, compilar a imagem Go, enviá-la ao registry local e aplicar o Deployment, Service ClusterIP e probes. | `kubectl get pods -o wide` indica o nó; `curl` via port-forward exercita o fluxo HTTP completo. |
| 7. Operação | Observar Pod, eventos e logs no CloudWatch local; em seguida destruir o Terraform. | Diferenciar problemas de API/IAM, nó indisponível, imagem sem pull e readiness falhando. |

## Pré-requisitos

- Linux com Docker daemon disponível e permissão para acessar `/var/run/docker.sock` (o k3s é iniciado pelo Ministack em modo privilegiado).
- Terraform >= 1.5, AWS CLI, `kubectl`, `make` e Docker; acesso aos registries das imagens do Ministack, k3s, Go e do coletor Fluent Bit. Go instalado no host é opcional (para `go test`/`go build` locais).
- Portas `4566`, `16443` e `5001` livres no host. O cluster sidecar publica `16443` diretamente no host; se mudar `EKS_BASE_PORT`, ajuste a porta esperada nas verificações.
- Memória e espaço para executar o k3s e baixar as imagens, além do próprio Ministack.

## Executar

Todos os comandos abaixo partem da raiz do repositório. O provider Terraform contém endpoints explícitos para os serviços AWS locais (incluindo CloudWatch Logs) e credenciais de teste; **não usa a conta AWS real**. O `Makefile` exporta as seguintes variáveis para seus comandos; se usar AWS CLI ou `kubectl` **diretamente em outro terminal**, exporte-as também:

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_EC2_METADATA_DISABLED=true
```

Execute esses `export` no terminal em que usar comandos `aws`/`kubectl` diretamente: variáveis definidas pelo `make` valem apenas durante a execução do alvo e não permanecem no seu shell.

1. Suba o emulador com socket Docker. A versão da imagem está fixada em `compose.yaml`:

   ```bash
   make up
   curl -fsS http://localhost:4566/_ministack/health
   aws sts get-caller-identity
   ```

   O STS local deve retornar a conta `000000000000`. **Não substitua** `test` por sua chave AWS real nem remova os endpoints locais ao executar este laboratório.

2. Inicialize, inspecione e aplique a infraestrutura:

   ```bash
   make init
   make validate
   make plan
   make apply
   make output
   aws eks describe-cluster --name ministack-lab --query 'cluster.[status,endpoint]' --output table
   aws eks describe-nodegroup --cluster-name ministack-lab --nodegroup-name workers --query 'nodegroup.[status,scalingConfig.desiredSize]' --output table
   ```

    O Terraform também cria `aws_ecr_repository.app` e o Log Group `/eks/ministack-lab/hello-eks` em `terraform/cloudwatch.tf` (retenção de sete dias); `make output` mostra os respectivos nomes/URIs. As receitas de `plan`/`apply` executam `validate` e `init` como dependências; `make apply` usa `-auto-approve`, então execute `make plan` antes se quiser revisar as alterações.

3. Configure um kubeconfig **isolado**, sem sobrescrever o contexto padrão do seu homelab:

   ```bash
   make kubeconfig
   export KUBECONFIG="$PWD/.kubeconfig-ministack"
   make status
   kubectl get pods -n kube-system
   ```

   Espere por pelo menos um nó `Ready`. Confirme que `aws eks describe-cluster` traz `certificateAuthority.data` preenchido. Se o cluster disser `ACTIVE`, mas não houver nó, veja `docker ps -a --filter name=ministack-eks-` e `docker compose logs ministack`: sem socket Docker ou com falha ao iniciar k3s, o Ministack pode responder à API EKS sem Kubernetes funcional.

 4. Publique `app/main.go` como imagem. O `app/Dockerfile` compila o Go em um estágio de build e executa o binário no contêiner final. O `make push` envia a imagem para `localhost:4566/hello-eks:v8`, endpoint Docker Registry V2 do ECR emulado; o k3s usa o mirror configurado pelo Ministack para puxá-la pelo URI `000000000000.dkr.ecr.us-east-1.amazonaws.com/hello-eks:v8` que está no Deployment:

   ```bash
    make push TAG=v8
   make deploy
   make status
   kubectl logs deployment/hello-eks
   ```

   Em um terminal, execute `make port-forward`; em outro, `curl http://localhost:5001/`. O JSON inclui `pod` e `node`, permitindo conferir com `make status`. `curl http://localhost:5001/healthz` testa a probe. O Service é `ClusterIP`: não depende de LoadBalancer/Ingress emulado.

    O `make deploy` aplica `k8s/cloudwatch.yaml`, `k8s/configmap.yaml` e `k8s/app.yaml` com `kubectl apply`. A chave `LOG_LEVEL` do ConfigMap chega ao contêiner como a variável `LOG_LEVEL`; `POD_NAME` e `NODE_NAME` continuam vindo do próprio Pod via Downward API (`fieldRef`).

    **Logs:** a aplicação escreve em `stdout`/`stderr`; o DaemonSet Fluent Bit em `k8s/cloudwatch.yaml` acompanha somente os arquivos `hello-eks` em `/var/log/containers` e envia suas linhas ao Log Group criado pelo Terraform. Cada Pod gera um stream `pod-...`. O coletor usa credenciais de laboratório `test/test` e o endpoint HTTP `ministack:4566` na rede Docker/k3s (`hostNetwork` com DNS Docker). Após acessar a aplicação, consulte:

    ```bash
    make logs
    # ou: aws logs tail /eks/ministack-lab/hello-eks --since 1h --follow
    ```

    Para verificar o coletor: `kubectl logs -n kube-system daemonset/hello-eks-logs`. Se editar `fluent-bit.conf`, incremente `config-revision` no template do DaemonSet para recarregar a configuração com `make deploy`. O estado de leitura dos arquivos fica no nó k3s em `/var/lib/hello-eks-fluent-bit`.

    **Nova versão:** altere `app/main.go`, execute `make push TAG=v9` (o alvo executa o build primeiro), troque o sufixo da imagem em `k8s/app.yaml` para `:v9` e execute `make deploy`. Como o template do Pod mudou, o Deployment inicia um RollingUpdate automaticamente. O `kubectl rollout status` apenas acompanha o andamento. Repetir `make deploy` sem mudar o template não cria novos Pods; **alterar apenas o ConfigMap não atualiza variáveis de ambiente em Pods existentes**: elas são lidas na criação do Pod. Use uma tag nova por release: o repositório está configurado como `IMMUTABLE` e o EKS não observa atualizações de tags no ECR.

   Em uma conta AWS real, o fluxo de build, push para ECR e mudança de tag no manifesto é o mesmo; o push usaria autenticação com `aws ecr get-login-password` e o URI ECR real. Aqui o registry Docker local dispensa login e não exige alterar DNS do host.

5. Limpe na ordem inversa, com o Ministack ainda ativo:

   ```bash
    kubectl delete -f k8s/app.yaml
    kubectl delete -f k8s/configmap.yaml
    kubectl delete -f k8s/cloudwatch.yaml
   make destroy
   make down
   ```

   O estado do Terraform fica em `terraform/terraform.tfstate` (ignorado pelo Git). Esta configuração não ativa persistência no Ministack: reiniciar/remover o contêiner perde os recursos emulados, podendo deixar o state Terraform desatualizado. Conclua `destroy` **antes** de parar o emulador quando possível.

## Além de criar o cluster: o que aparece em um EKS de verdade?

1. **Rede e segurança:** subnets em duas ou mais AZs; privadas para workers e NAT ou VPC endpoints para saída, se o desenho pedir; security groups e regras de acesso à API. Aqui escolhemos subnets públicas e uma rota simples para estudar as dependências sem NAT. A saída da aplicação de teste não passa por essa VPC simulada.
2. **IAM e acesso:** papel do control plane, papel dos workers e access entries/políticas EKS para operadores. Para serviços que chamam AWS a partir de Pods, estudar EKS Pod Identity (ou IRSA com OIDC), com políticas de menor privilégio. O bootstrap do criador do cluster já permite o `kubectl` neste cenário de teste.
3. **Capacidade:** managed node groups (EC2) ou Fargate na AWS real; tamanho mínimo/desejado/máximo e upgrades. O `desired_size = 1` deste laboratório não determina a quantidade de nós k3s. Para aprender scheduling aqui, consulte `kubectl get nodes` e o campo `NODE` dos Pods.
4. **Rede e DNS dos Pods:** em EKS normalmente são usados os add-ons gerenciados VPC CNI, CoreDNS e kube-proxy. O sidecar k3s já traz rede flannel, CoreDNS e kube-proxy; registrar `aws_eks_addon` no Ministack **não instala nem atualiza** esses componentes dentro do k3s. No laboratório evitamos declarar add-ons fictícios.
5. **Publicação e dados:** Service `ClusterIP` + `port-forward` bastam aqui. Na AWS, exposição HTTP costuma usar AWS Load Balancer Controller + ALB/Ingress (ou NLB para Service LoadBalancer); volumes persistentes envolvem EBS CSI driver e `StorageClass`. Não são necessários para esta app sem estado.
6. **Operação habitual:** métricas/logs e alertas (CloudWatch ou Prometheus/Grafana), políticas de acesso Kubernetes, health probes, requests/limits, autoscaling (HPA + Cluster Autoscaler/Karpenter conforme o caso), upgrades e backups. Escolha essas peças de acordo com o workload; **Argo CD e pipeline CI/CD não são pré-requisitos para subir um EKS**.

### Onde a simulação para

O Ministack emula o *control plane AWS* do EKS e sobe um Kubernetes k3s utilizável, mas não reproduz um control plane EKS gerenciado, instâncias EC2 de node groups, ENIs/VPC CNI, rede de VPC, alta disponibilidade entre AZs ou instalação real dos add-ons EKS. O teste confirma Terraform → API EKS local → kubeconfig → API Kubernetes → Pod/Service, e não a criação de um worker EC2 independente.

**Fontes consultadas:** [documentação EKS do Ministack](https://ministack.org/docs/services/eks/), [ECR do Ministack](https://ministack.org/docs/services/ecr/), [Terraform com Ministack](https://ministack.org/docs/iac), [limitações conhecidas](https://ministack.org/docs/limitations), [implementação EKS](https://github.com/ministackorg/ministack/blob/main/ministack/services/eks.py) e [repositório do projeto](https://github.com/ministackorg/ministack). Verificado com a imagem `1.5.18` e `hashicorp/aws` `5.100.0`.
