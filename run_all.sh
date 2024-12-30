#!/bin/bash

# 初始化变量
sbatch_nodes=("g3005" "g3006" "g3007" "g3008")
HF_MODEL_NAME="/data/public/wangshuo/LongContext/model/Qwen/Qwen2.5-72B-Instruct-AWQ-YARN-128k"
INFER_TYPE="vLLM"
PER_PROC_GPUS=2
PORT=19645
ENV_NAME="gunicorn"
JOB_NAME="vllm_job"
NGINX_CONF="./nginx_docker/nginx/nginx.conf"
node_port=$((PORT + 1))
CHECK_INTERVAL=10  # 检查间隔时间（秒）
MAX_FAILURES=6     # 最大失败次数

# 创建日志目录
mkdir -p ./log

# 生成 Nginx 配置文件
generate_nginx_conf() {
    mkdir -p "$(dirname "$NGINX_CONF")"
    cat >$NGINX_CONF <<EOL
worker_processes auto;
events {
    use epoll;
    multi_accept on;
}
http{   
    upstream backend {
        least_conn;
EOL

    for node in "${sbatch_nodes[@]}"; do
        echo "        server $node:$node_port max_fails=3 fail_timeout=10000s;" >>$NGINX_CONF
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
            proxy_read_timeout 600s;
            proxy_connect_timeout 600s;
        }
    }
}
EOL

    echo "Nginx configuration file generated at $NGINX_CONF"
}

# 提交 Slurm 任务并获取 jobid
submit_slurm_job() {
    local node=$1
    jobid=$(sbatch --job-name=$JOB_NAME \
        --partition=xl \
        --nodes=1 \
        --nodelist="$node" \
        --ntasks-per-node=8 \
        --gres=gpu:8 \
        --cpus-per-task=8 \
        --output="./log/job_$node.log" \
        --wrap="bash ./scripts/run_vllm.sh $HF_MODEL_NAME $INFER_TYPE $PER_PROC_GPUS $node_port $ENV_NAME" | awk '{print $4}')
    echo "vLLM backend starting on $node with jobid $jobid"
    echo $jobid > "./log/jobid_$node.log"
}

submit_slurm_jobs() {
    squeue | grep $JOB_NAME | awk '{print $1}' | xargs -n1 scancel
    for node in "${sbatch_nodes[@]}"; do
        submit_slurm_job $node
    done
}

# 清理函数
cleanup() {
    echo "Cleaning up..."
    docker rm -f nginx-lb
    squeue | grep $JOB_NAME | awk '{print $1}' | xargs -n1 scancel
}

# 捕获退出信号以终止容器和 Slurm 任务
trap 'cleanup' EXIT

# 生成 Nginx 配置文件并提交 Slurm 任务
generate_nginx_conf
submit_slurm_jobs
# bash start_docker.sh $PORT

# 监控 upstream 服务器状态
UPSTREAM_SERVERS=()
for node in "${sbatch_nodes[@]}"; do
    UPSTREAM_SERVERS+=("$node:$node_port")
done

declare -A FAILURE_COUNT

# 初始化失败计数
for server in "${UPSTREAM_SERVERS[@]}"; do
    FAILURE_COUNT[$server]=0
done

check_upstream() {
    for server in "${UPSTREAM_SERVERS[@]}"; do
        host=$(echo $server | cut -d':' -f1)
        port=$(echo $server | cut -d':' -f2)
        if nc -z -w 5 $host $port; then
            FAILURE_COUNT[$server]=0
            echo "Server $server is up"
        else
            FAILURE_COUNT[$server]=$((FAILURE_COUNT[$server] + 1))
            echo "Server $server is down, current failure count: ${FAILURE_COUNT[$server]}"
        fi

        if [ "${FAILURE_COUNT[$server]}" -ge "$MAX_FAILURES" ]; then
            echo "Server $server has failed $MAX_FAILURES times, restarting..."
            node=$(echo $server | cut -d':' -f1)
            if [ -f "./log/jobid_$node.log" ]; then
                old_jobid=$(cat "./log/jobid_$node.log")
                scancel $old_jobid
            fi
            submit_slurm_job $node
            FAILURE_COUNT[$server]=0
        fi
    done
}

while true; do
    echo -ne "\033[2J\033[H"
    check_upstream
    for ((i=CHECK_INTERVAL; i>0; i--)); do
        echo -ne "$(date), Sleeping for $i seconds... \t| Ctrl C to exit\r"
        sleep 1
    done
done