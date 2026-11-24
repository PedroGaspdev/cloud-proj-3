require "dotenv/load"
require "shellwords"

REPOSITORY_URL = "https://github.com/PedroGaspdev/cloud-proj-3.git"
REPOSITORY_BRANCH = ENV.fetch("APP_GIT_BRANCH", "main")
SOURCE_DIR = File.expand_path(".vagrant/project-source", __dir__)

required_env = %w[DB_NAME DB_USER DB_PASSWORD MYSQL_ROOT_PASSWORD JWT_SECRET]
missing_env = required_env.reject { |key| ENV.key?(key) && !ENV[key].empty? }
unless missing_env.empty?
  raise "Variáveis ausentes no .env: #{missing_env.join(', ')}"
end

DB_HOST = ENV.fetch("DB_HOST", "db")
unless DB_HOST == "db"
  raise "DB_HOST deve ser 'db' para resolver o banco pela rede Docker."
end

Vagrant.configure("2") do |config|
  config.trigger.before :up do |trigger|
    trigger.name = "Clonar/atualizar o projeto e preparar a rede Docker"
    trigger.run = {
      inline: <<~SHELL
        mkdir -p #{Shellwords.escape(File.dirname(SOURCE_DIR))}
        if [ ! -d #{Shellwords.escape(File.join(SOURCE_DIR, ".git"))} ]; then
          git clone --depth 1 --single-branch \
            --branch #{Shellwords.escape(REPOSITORY_BRANCH)} \
            -- #{Shellwords.escape(REPOSITORY_URL)} \
            #{Shellwords.escape(SOURCE_DIR)}
        fi
        docker build --tag clube-app:local #{Shellwords.escape(SOURCE_DIR)}
        if docker network inspect rede_interna >/dev/null 2>&1; then
          if [ "$(docker network inspect --format='{{.Internal}}' rede_interna)" != "true" ]; then
            echo "A rede rede_interna existe, mas nao esta marcada como interna." >&2
            exit 1
          fi
        else
          docker network create --internal rede_interna
        fi
      SHELL
    }
  end

  config.vm.define "DB" do |db|
    db.vm.provider "docker" do |docker|
      docker.image = "mysql:8"
      docker.name = "clube-db"
      docker.create_args = [
        "--network=rede_interna",
        "--network-alias=db"
      ]
      docker.env = {
        "MYSQL_DATABASE" => ENV.fetch("DB_NAME"),
        "MYSQL_USER" => ENV.fetch("DB_USER"),
        "MYSQL_PASSWORD" => ENV.fetch("DB_PASSWORD"),
        "MYSQL_ROOT_PASSWORD" => ENV.fetch("MYSQL_ROOT_PASSWORD")
      }
      docker.volumes = [
        "clube_mysql_data:/var/lib/mysql",
        "#{SOURCE_DIR}/db/schema.sql:/docker-entrypoint-initdb.d/01-schema.sql:ro,Z",
        "#{SOURCE_DIR}/db/seed.sql:/docker-entrypoint-initdb.d/02-seed.sql:ro,Z"
      ]
    end
  end

  config.vm.define "appserver" do |app|
    app.vm.provider "docker" do |docker|
      docker.image = "clube-app:local"
      docker.name = "clube-app"
      docker.create_args = [
        "--network=rede_interna",
        "--network-alias=appserver"
      ]
      docker.env = {
        "DB_HOST" => DB_HOST,
        "DB_PORT" => ENV.fetch("DB_PORT", "3306"),
        "DB_NAME" => ENV.fetch("DB_NAME"),
        "DB_USER" => ENV.fetch("DB_USER"),
        "DB_PASSWORD" => ENV.fetch("DB_PASSWORD"),
        "JWT_SECRET" => ENV.fetch("JWT_SECRET"),
        "COOKIE_SECURE" => ENV.fetch("COOKIE_SECURE", "false")
      }
    end
  end

  config.vm.define "proxy" do |proxy|
    proxy.vm.provider "docker" do |docker|
      docker.image = "nginx:alpine"
      docker.name = "clube-proxy"
      docker.create_args = ["--network=rede_interna"]
      docker.ports = ["127.0.0.1:8080:80"]
      docker.volumes = [
        "#{SOURCE_DIR}/nginx/reverse-proxy.conf:/etc/nginx/conf.d/default.conf:ro,Z"
      ]
    end
  end
end
