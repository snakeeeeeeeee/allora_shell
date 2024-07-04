#!/bin/bash

BOLD="\033[1m"
UNDERLINE="\033[4m"
DARK_YELLOW="\033[0;33m"
CYAN="\033[0;36m"
RESET="\033[0;32m"

function install_base() {
	echo "正在升级安装基础依赖..."
	# 升级所有已安装的包
	sudo apt update
	# 安装基本组件
	sudo apt install pkg-config curl build-essential libssl-dev libclang-dev ufw docker-compose-plugin git wget htop tmux jq make lz4 gcc unzip liblz4-tool -y
}


function install_docker() {
    # 检查 Docker 是否已安装
    if ! command -v docker &> /dev/null; then
        # 如果 Docker 未安装，则进行安装
        echo "未检测到 Docker，正在安装..."
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg lsb-release

        # 添加 Docker 官方 GPG 密钥
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

        # 设置 Docker 仓库
        echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        # 授权 Docker 文件
        sudo chmod a+r /etc/apt/keyrings/docker.gpg

        # 更新 apt 包索引
        sudo apt-get update

        # 安装 Docker Engine，CLI 和 Containerd
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    else
        echo "Docker 已安装。"
    fi

    # 检查 docker-compose 是否已安装
    if ! command -v docker-compose &> /dev/null; then
        echo "未检测到 docker-compose，正在安装..."

        # 安装 docker-compose
        sudo apt-get install -y docker-compose
    else
        echo "docker-compose 已安装。"
    fi
}


# 检查并安装 Node.js 和 npm
function install_nodejs_and_npm() {
    if command -v node > /dev/null 2>&1; then
        echo "Node.js 已安装"
    else
        echo "Node.js 未安装，正在安装..."
        curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi

    if command -v npm > /dev/null 2>&1; then
        echo "npm 已安装"
    else
        echo "npm 未安装，正在安装..."
        sudo apt-get install -y npm
    fi
}

# 检查并安装 PM2
function install_pm2() {
    if command -v pm2 > /dev/null 2>&1; then
        echo "PM2 已安装"
    else
        echo "PM2 未安装，正在安装..."
        npm install pm2@latest -g
    fi
}

# 检查Go环境
function check_go_installation() {
    if command -v go > /dev/null 2>&1; then
        echo "Go 环境已安装"
        return 0
    else
        echo "Go 环境未安装，正在安装..."
        return 1
    fi
}



function install_go() {
	# 安装 Go
    if ! check_go_installation; then
        sudo rm -rf /usr/local/go
        curl -L https://go.dev/dl/go1.22.0.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
        echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
        source $HOME/.bash_profile
        go version
    fi
}


function install_python() {
    # 安装 python
    if command -v python3 &>/dev/null; then
        echo "Python is installed."
    else
        echo "Python is not installed. Installing..."
        sudo apt update
        sudo apt install -y python3
    fi

    # 检查pip
    if command -v pip3 &>/dev/null; then
        echo "pip 已安装."
    else
        echo "pip 未安装, 开始安装..."
        sudo apt update
        sudo apt install -y python3-pip
    fi


    if command -v python3 &>/dev/null && command -v pip3 &>/dev/null; then
        echo "python 安装成功"
    else
        echo "python 安装失败"
    fi
}

function do_install_worker() {
    # 安装allocmd
    pip install allocmd --upgrade

    # 创建worker
    read -p "请输入worker名称: " dir_name
    mkdir -p $dir_name/worker/data/head
    mkdir -p $dir_name/worker/data/worker
    chmod -R 777 ./$dir_name/worker/data/head
    chmod -R 777 ./$dir_name/worker/data/worker

    allocmd generate worker --name $dir_name --topic 1 --env dev
    cd $HOME/$dir_name/worker


    # 更新config.yaml的hex_coded_pk
    hex_coded_pk="$(echo "y" | allorad keys export "$dir_name" --keyring-backend test --unarmored-hex --unsafe)"
    hex_coded_pk=$(echo "$hex_coded_pk" | tail -n 1)
    sed -i "s|hex_coded_pk: .*|hex_coded_pk: $hex_coded_pk|" config.yaml


    # 更新config.yaml的boot_nodes
    sed -i 's|boot_nodes: .*|boot_nodes: /dns4/head-0-p2p.edgenet.allora.network/tcp/32080/p2p/12D3KooWQgcJ4wiHBWE6H9FxZAVUn84ZAmywQdRk83op2EibWTiZ,/dns4/head-1-p2p.edgenet.allora.network/tcp/32081/p2p/12D3KooWCyao1YJ9DDZEAV8ZUZ1MLLKbcuxVNju1QkTVpanN9iku,/dns4/head-2-p2p.edgenet.allora.network/tcp/32082/p2p/12D3KooWKZYNUWBjnAvun6yc7EBnPvesX23e5F4HGkEk1p5Q7JfK|' config.yaml


    #拉取依赖文件
curl -o Dockerfile https://raw.githubusercontent.com/snakeeeeeeeee/allora_shell/main/Dockerfile
curl -o Dockerfile_inference https://raw.githubusercontent.com/snakeeeeeeeee/allora_shell/main/Dockerfile_inference
curl -o requirements.txt https://raw.githubusercontent.com/snakeeeeeeeee/allora_shell/main/requirements.txt
curl -o app.py https://raw.githubusercontent.com/snakeeeeeeeee/allora_shell/main/app.py
curl -o main.py https://raw.githubusercontent.com/snakeeeeeeeee/allora_shell/main/main.py

    # 初始化worker
    allocmd generate worker --env prod && chmod -R +rx ./data/scripts


# 设置prod-docker-compose
sed -i '/services:/a\
  inference:\
    container_name: inference-hf\
    build:\
      context: .\
      dockerfile: Dockerfile_inference\
    command: python -u /app/app.py\
    ports:\
      - "8000:8000"' prod-docker-compose.yaml

    # 构建镜像
    docker compose -f prod-docker-compose.yaml build
    sleep 10

    # 构建运行镜像
    docker compose -f prod-docker-compose.yaml up -d
}

function do_install_worker2() {
  cd $HOME
  echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}Installing Allorand...${RESET}"
  git clone https://github.com/allora-network/allora-chain.git
  cd allora-chain && make all
  echo

  echo -e "${BOLD}${DARK_YELLOW}Checking allorand version...${RESET}"
  allorad version
  echo

  echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}Importing wallet...${RESET}"
  allorad keys add testkey --recover
  echo

  echo "Request faucet to your wallet from this link: https://faucet.edgenet.allora.network/"
  echo

  echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}Installing worker node...${RESET}"
  git clone https://github.com/allora-network/basic-coin-prediction-node
  cd basic-coin-prediction-node
  mkdir worker-data
  mkdir head-data
  echo

  echo -e "${BOLD}${DARK_YELLOW}Giving permissions...${RESET}"
  sudo chmod -R 777 worker-data head-data
  echo

  echo -e "${BOLD}${DARK_YELLOW}Creating Head keys...${RESET}"
  echo
  sudo docker run -it --entrypoint=bash -v $(pwd)/head-data:/data alloranetwork/allora-inference-base:latest -c "mkdir -p /data/keys && (cd /data/keys && allora-keys)"
  echo
  sudo docker run -it --entrypoint=bash -v $(pwd)/worker-data:/data alloranetwork/allora-inference-base:latest -c "mkdir -p /data/keys && (cd /data/keys && allora-keys)"
  echo

  echo -e "${BOLD}${DARK_YELLOW}This is your Head ID:${RESET}"
  cat head-data/keys/identity
  echo

  if [ -f docker-compose.yml ]; then
      rm docker-compose.yml
      echo "Removed existing docker-compose.yml file."
      echo
  fi

  read -p "Enter HEAD_ID: " HEAD_ID
  echo

  read -p "Enter WALLET_SEED_PHRASE: " WALLET_SEED_PHRASE
  echo

  echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}Generating docker-compose.yml file...${RESET}"

cat <<EOF > docker-compose.yml
version: '3'
services:
  inference:
    container_name: inference-basic-eth-pred
    build:
      context: .
    command: python -u /app/app.py
    ports:
      - "8000:8000"
    networks:
      eth-model-local:
        aliases:
          - inference
        ipv4_address: 172.22.0.4
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/inference/ETH"]
      interval: 10s
      timeout: 10s
      retries: 12
    volumes:
      - ./inference-data:/app/data

  updater:
    container_name: updater-basic-eth-pred
    build: .
    environment:
      - INFERENCE_API_ADDRESS=http://inference:8000
    command: >
      sh -c "
      while true; do
        python -u /app/update_app.py;
        sleep 24h;
      done
      "
    depends_on:
      inference:
        condition: service_healthy
    networks:
      eth-model-local:
        aliases:
          - updater
        ipv4_address: 172.22.0.5

  worker:
    container_name: worker-basic-eth-pred
    environment:
      - INFERENCE_API_ADDRESS=http://inference:8000
      - HOME=/data
    build:
      context: .
      dockerfile: Dockerfile_b7s
    entrypoint:
      - "/bin/bash"
      - "-c"
      - |
        if [ ! -f /data/keys/priv.bin ]; then
          echo "Generating new private keys..."
          mkdir -p /data/keys
          cd /data/keys
          allora-keys
        fi
        allora-node --role=worker --peer-db=/data/peerdb --function-db=/data/function-db \
          --runtime-path=/app/runtime --runtime-cli=bls-runtime --workspace=/data/workspace \
          --private-key=/data/keys/priv.bin --log-level=debug --port=9011 \
          --boot-nodes=/ip4/172.22.0.100/tcp/9010/p2p/$HEAD_ID \
          --topic=allora-topic-1-worker \
          --allora-chain-key-name=testkey \
          --allora-chain-restore-mnemonic='$WALLET_SEED_PHRASE' \
          --allora-node-rpc-address=https://allora-rpc.edgenet.allora.network/ \
          --allora-chain-topic-id=allora-topic-1-worker
    volumes:
      - ./worker-data:/data
    working_dir: /data
    depends_on:
      - inference
      - head
    networks:
      eth-model-local:
        aliases:
          - worker
        ipv4_address: 172.22.0.10

  head:
    container_name: head-basic-eth-pred
    image: alloranetwork/allora-inference-base-head:latest
    environment:
      - HOME=/data
    entrypoint:
      - "/bin/bash"
      - "-c"
      - |
        if [ ! -f /data/keys/priv.bin ]; then
          echo "Generating new private keys..."
          mkdir -p /data/keys
          cd /data/keys
          allora-keys
        fi
        allora-node --role=head --peer-db=/data/peerdb --function-db=/data/function-db  \
          --runtime-path=/app/runtime --runtime-cli=bls-runtime --workspace=/data/workspace \
          --private-key=/data/keys/priv.bin --log-level=debug --port=9010 --rest-api=:6000
    ports:
      - "6000:6000"
    volumes:
      - ./head-data:/data
    working_dir: /data
    networks:
      eth-model-local:
        aliases:
          - head
        ipv4_address: 172.22.0.100

networks:
  eth-model-local:
    driver: bridge
    ipam:
      config:
        - subnet: 172.22.0.0/24

volumes:
  inference-data:
  worker-data:
  head-data:
EOF

  echo -e "${BOLD}${DARK_YELLOW}docker-compose.yml file generated successfully!${RESET}"
  echo

  echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}Building and starting Docker containers...${RESET}"
  docker-compose build
  docker-compose up -d
  echo

  echo -e "${BOLD}${DARK_YELLOW}Checking running Docker containers...${RESET}"
  docker ps
}

function install_worker() {
	# base
	install_base
  # python
  install_python
	# docker
	#install_docker
  do_install_worker2
}


# 主菜单
function main_menu() {
    clear
    echo "=====================安装及常规修改功能========================="
    echo "请选择要执行的操作:"
    echo "1. 安装worker"
    read -p "请输入选项: " OPTION

    case $OPTION in
    1) install_worker ;;
    2) query_log ;;
    *) echo "无效选项。" ;;
    esac
}

# 显示主菜单
main_menu
