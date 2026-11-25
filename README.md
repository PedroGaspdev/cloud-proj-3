# Projeto 03 — Computação em Nuvem

Aplicação de reserva de quadras construída com Next.js 16 e MySQL 8. O Vagrant
gerencia os contêineres Docker da aplicação, do banco e do proxy reverso Nginx.

## Arquitetura

```text
Navegador -- http://localhost:8080 --> proxy (Nginx)
                                         ├── rede_interna ── appserver ── DB
                                         └── rede_externa ── porta do hospedeiro
```

O Nginx encaminha para `appserver:3000`; a aplicação conecta ao MySQL pelo
alias `db`. O proxy participa das duas redes: `rede_interna` conecta os
serviços sem expor o app ou o banco, e `rede_externa` permite publicar a porta
`8080` no hospedeiro. As portas da aplicação e do banco não são publicadas. O
banco persiste em um volume Docker nomeado.

| Serviço | Imagem/construção | Rede | Porta no hospedeiro |
|---|---|---|---|
| `proxy` | `nginx:alpine` | `rede_interna`, `rede_externa` | `127.0.0.1:8080` |
| `appserver` | build do `Dockerfile` | `rede_interna` | nenhuma |
| `DB` | `mysql:8` | `rede_interna` | nenhuma |

## Requisitos

O roteiro de implantação usa Fedora Linux, Docker Engine, Git e Vagrant 2.4 ou
mais recente. VirtualBox não é usado nessa arquitetura.

Instale Docker, Vagrant e Git de acordo com a documentação oficial do sistema.
No Fedora, habilite o Docker e associe seu usuário ao grupo `docker`; saia e
entre novamente para aplicar a permissão:

```bash
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
vagrant plugin install dotenv
```

Os triggers usados pelo Vagrantfile são parte do Vagrant 2.4 ou mais recente;
não instale o plugin comunitário `vagrant-triggers`, que conflita com o recurso
interno.

## Configuração e inicialização

O primeiro clone do repositório fornece o Vagrantfile que inicia o ambiente:

```bash
git clone https://github.com/PedroGaspdev/cloud-proj-3.git
cd cloud-proj-3
cp .env.example .env
```

Edite `.env` e substitua os valores de exemplo por segredos locais. `DB_HOST`
deve ser `db`; gere `JWT_SECRET` com `openssl rand -base64 32`. Use senhas
diferentes para `DB_PASSWORD` e `MYSQL_ROOT_PASSWORD`. Não versione `.env`.

Valide e suba a stack:

```bash
vagrant validate
vagrant up --provider=docker --no-parallel
vagrant status
```

O trigger do Vagrant clona a branch `main` do GitHub em
`.vagrant/project-source` na primeira execução e constrói a imagem do app. O
Dockerfile, os scripts SQL e a configuração Nginx são usados a partir desse
checkout. O Vagrantfile precisa estar disponível localmente antes do primeiro
`vagrant up`; um Vagrantfile não pode clonar a si próprio antes de ser lido.
Para usar outra branch, defina `APP_GIT_BRANCH` no ambiente antes de executar
o Vagrant. Publique no GitHub as alterações do Dockerfile, do Vagrantfile e da
aplicação antes de subir: o build usa o checkout remoto, não alterações locais
que ainda não foram enviadas.

Abra **http://localhost:8080**. No Fedora com SELinux Enforcing, os bind mounts
somente de leitura usam o rótulo `:ro,Z`.

Para o passo a passo completo, incluindo detalhes de instalação, configuração,
validação e bootstrap, consulte [GUIA-CONTEINERIZACAO-VAGRANT-DOCKER.md](./GUIA-CONTEINERIZACAO-VAGRANT-DOCKER.md).

## Operação

| Ação | Comando |
|---|---|
| Iniciar os serviços | `vagrant up --provider=docker --no-parallel` |
| Parar sem apagar os dados | `vagrant halt` |
| Ver o estado | `vagrant status` |
| Ver logs | `docker logs -f clube-app` |
| Inspecionar redes | `docker network inspect rede_interna rede_externa` |
| Acessar o MySQL | `docker exec -it clube-db mysql -u root -p` |

O checkout em `.vagrant/project-source` é separado da cópia de trabalho usada
para executar o Vagrant. Para atualizá-lo e reconstruir a aplicação:

```bash
git -C .vagrant/project-source pull --ff-only
vagrant destroy -f appserver
vagrant up appserver --provider=docker
```

Para apagar também os dados persistidos do banco:

```bash
vagrant destroy -f
docker volume rm clube_mysql_data
```

O MySQL executa `db/schema.sql` e `db/seed.sql` somente quando o volume de
dados está vazio. Remover o volume apaga contas, reservas e demais dados.

## Aplicação

A aplicação contém cadastro e login, área de cliente, reservas de quadras e
dashboard administrativo. O `seed.sql` fornece contas de demonstração para
desenvolvimento; não reutilize essas credenciais em produção.

- Senhas armazenadas como hashes bcrypt; consultas SQL usam prepared
  statements.
- O login emite um JWT assinado com `JWT_SECRET`, armazenado em cookie `httpOnly`.
- `web/proxy.ts` protege as rotas administrativas, do cliente e APIs de reservas.
- O cadastro público cria contas de cliente; o papel de administrador vem do
  seed, não de dados enviados pelo navegador.

Para inspecionar falhas de inicialização:

```bash
docker logs clube-proxy
docker logs clube-app
docker logs clube-db
```
