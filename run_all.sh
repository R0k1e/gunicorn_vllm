#!/bin/bash

# 初始化变量
sbatch_nodes=("g3005" "g3006" "g3007" "g3008")
HF_MODEL_NAME="/data/public/wangshuo/LongContext/model/Qwen/Qwen2.5-72B-Instruct-AWQ-YARN-128k"
# HF_MODEL_NAME="/data/public/wangshuo/LongContext/model/meta-llama/Llama-3.3-70B-Instruct"
INFER_TYPE="vLLM"
PER_PROC_GPUS=2
PORT=29666
ENV_NAME="gunicorn"
JOB_NAME="vllm_job"
NGINX_CONF="./nginx_docker/nginx/nginx.conf"
CHECK_INTERVAL=60 # 检查间隔时间（秒）
CHECK_LOG_LENGTH=1000
START_TIME=$(date +"%Y_%m_%d-%H:%M:%S")
LOG_DIR="./log/$START_TIME"
node_port=$((PORT + 1))
# 创建日志目录
mkdir -p $LOG_DIR

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
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log /usr/local/bin/log/$START_TIME/access.log main;
    error_log /usr/local/bin/log/$START_TIME/error.log warn;
    upstream backend {
        least_conn;
EOL

    for node in "${sbatch_nodes[@]}"; do
        echo "        server $node:$node_port max_fails=10 fail_timeout=300s;" >>$NGINX_CONF
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
            proxy_read_timeout 300s;
            proxy_connect_timeout 300s;
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
        --output="$LOG_DIR/job_$node.log" \
        --wrap="bash ./scripts/run_vllm.sh $HF_MODEL_NAME $INFER_TYPE $PER_PROC_GPUS $node_port $ENV_NAME" | awk '{print $4}')
    echo "vLLM backend starting on $node with jobid $jobid"
    echo $jobid >"$LOG_DIR/jobid_$node.log"
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
declare -A SERVER_LIFETIME

# 初始化失败计数和服务器寿命
for server in "${UPSTREAM_SERVERS[@]}"; do
    FAILURE_COUNT[$server]=0
    jitter=$(shuf -i 1-60 -n 1)                                          # 生成1到60之间的随机数作为抖动
    SERVER_LIFETIME[$server]=$((JOB_LIFETIME + jitter * CHECK_INTERVAL)) # 假设 JOB_LIFETIME 是预定义的超参数，表示每个 job 的寿命
done

check_upstream() {
    for server in "${UPSTREAM_SERVERS[@]}"; do
        node=$(echo $server | cut -d':' -f1)
        log_file="$LOG_DIR/job_${node}.log"
        tail -n $CHECK_LOG_LENGTH "$log_file" | grep -q "ERROR" # 检查日志最后1000行
        if [ $? -eq 0 ]; then
            echo "Server $server is error: Error detected in log file $log_file. Restarting services..."
            old_jobid=$(cat "$LOG_DIR/jobid_$node.log")
            scancel $old_jobid
            sleep 10
            submit_slurm_job $node       
        else
            echo "Server $server is up"
        fi
    done
}

restart_expired_jobs() {
    for server in "${UPSTREAM_SERVERS[@]}"; do
        if [ "${SERVER_LIFETIME[$server]}" -le 0 ]; then
            echo "Server $server has reached its lifetime, restarting..."
            node=$(echo $server | cut -d':' -f1)
            if [ -f "$LOG_DIR/jobid_$node.log" ]; then
                old_jobid=$(cat "$LOG_DIR/jobid_$node.log")
                scancel $old_jobid
                sleep 3
            fi
            submit_slurm_job $node
            jitter=$(shuf -i 1-60 -n 1)                                          # 生成1到60之间的随机数作为抖动
            SERVER_LIFETIME[$server]=$((JOB_LIFETIME + jitter * CHECK_INTERVAL)) # 重启后刷新寿命并添加抖动
        fi
    done
}

while true; do
    echo -ne "\033[2J\033[H"
    check_upstream
    # restart_expired_jobs
    for server in "${UPSTREAM_SERVERS[@]}"; do
        SERVER_LIFETIME[$server]=$((SERVER_LIFETIME[$server] - CHECK_INTERVAL))
    done
    for ((i = CHECK_INTERVAL; i > 0; i--)); do
        echo -ne "$(date), Sleeping for $i seconds... \t| Ctrl C to exit\r"
        sleep 1
    done
done
