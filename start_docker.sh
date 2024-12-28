PORT=$1
start_docker() {
    docker rm -f nginx-lb
    docker run -i -p $PORT:80 \
        -v ./nginx_docker/nginx/nginx.conf:/etc/nginx/nginx.conf \
        -v ./scripts/start_services.sh:/usr/local/bin/start_services.sh \
        -v ./scripts/run_vllm.sh:/usr/local/bin/run_vllm.sh \
        -v ./log:/usr/local/bin/log \
        --name nginx-lb nginx-lb:latest

    # 输出 Docker 日志
    docker logs -ft nginx-lb| tee ./log/nginx-lb.log
}

start_docker