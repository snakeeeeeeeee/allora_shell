#!/bin/bash


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
    curl -o Dockerfile https://raw.githubusercontent.com/snakeeeeeeeee/allora_shell/main/Dockerfile_inference
    curl -o Dockerfile https://raw.githubusercontent.com/snakeeeeeeeee/allora_shell/main/requirements.txt
    curl -o Dockerfile https://raw.githubusercontent.com/snakeeeeeeeee/allora_shell/main/app.py
    curl -o Dockerfile https://raw.githubusercontent.com/snakeeeeeeeee/allora_shell/main/main.py

    # 初始化worker
    allocmd generate worker --env prod && chmod -R +rx ./data/scripts
    

    # 添加inference服务到prod-docker-compose.yaml
    sed -i '/services:/a\
  inference:\
    container_name: inference-hf\
    build:\
      context: .\
      dockerfile: Dockerfile_inference\
    command: python -u /app/app.py\
    ports:\
      - "8000:8000"' prod-docker-compose.yaml

    # 构建运行镜像
    docker compose -f prod-docker-compose.yaml up --build -d
}



function install_worker() {
	# base
	install_base
    	# python
    	install_python
	# docker
	install_docker
 	# install worker
  	do_install_worker
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
