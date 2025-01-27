PORT=$1

docker rm -f nginx-lb

if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
    echo "Error: Port must be a number."
    exit 1
fi

# 检测端口是否被占用
if netstat -tuln | grep -q ":$PORT "; then
    echo "Error: Port $PORT is already in use."
    exit 1
fi

start_docker() {
    docker rm -f nginx-lb
    docker run -i -p $PORT:80 \
        -v ./nginx_docker/nginx/nginx.conf:/etc/nginx/nginx.conf \
        -v ./scripts/start_services.sh:/usr/local/bin/start_services.sh \
        -v ./scripts/run_vllm.sh:/usr/local/bin/run_vllm.sh \
        -v ./log:/usr/local/bin/log \
        --name nginx-lb nginx-lb:latest
}

start_docker