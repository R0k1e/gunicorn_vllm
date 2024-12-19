#!/bin/bash
sbatch_nodes=("g3005" "g3003")
HF_MODEL_NAME="/data/public/wangshuo/LongContext/model/Qwen/Qwen2.5-72B-Instruct-AWQ"
INFER_TYPE="vLLM"
PER_PROC_GPUS=2
PORT=39875
ENV_NAME="gunicorn"

mkdir -p ./log

# 生成 Nginx 配置文件
NGINX_CONF="./nginx_docker/nginx.conf"
mkdir -p ./nginx_docker
cat >$NGINX_CONF <<EOL
upstream backend {
    least_conn;
EOL

for node in "${sbatch_nodes[@]}"; do
    echo "    server $node:$PORT max_fails=3 fail_timeout=10000s;" >>$NGINX_CONF
done

cat >>$NGINX_CONF <<EOL
}

server {
    listen 80;

    location /infer {
        proxy_pass http://backend/infer;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

echo "Nginx configuration file generated at $NGINX_CONF"

# 杀死所有之前提交的 vllm 推理任务
squeue | grep "vllm_job" | awk '{print $1}' | xargs -n1 scancel

for node in "${sbatch_nodes[@]}"; do
    sbatch --job-name=vllm_job \
        --partition=xl \
        --nodes=1 \
        --nodelist="$node" \
        --ntasks-per-node=8 \
        --gres=gpu:2 \
        --cpus-per-task=8 \
        --output="./log/job_$node.log" \
        --wrap="bash ./scripts/run_vllm.sh $HF_MODEL_NAME $INFER_TYPE $PER_PROC_GPUS $PORT $ENV_NAME"
    echo "vLLM backend started on $node"
done

docker rm -f nginx-lb

# #itd
docker run -itd -p $PORT:80 \
    -v ./nginx_docker/nginx.conf:/etc/nginx/conf.d/default.conf \
    -v ./scripts/start_services.sh:/usr/local/bin/start_services.sh \
    -v ./scripts/run_vllm.sh:/usr/local/bin/run_vllm.sh \
    -v ./log:/usr/local/bin/log \
    --name nginx-lb nginx-lb:latest
