# 使用 source 执行，需要在当前 shell中有效
module load rootless-docker/default
#注意使用bash（不能用zsh）
start_rootless_docker.sh
sleep 1
docker load -i ./nginx_docker/nginx.tar
docker build . -f ./nginx_docker/Dockerfile.nginx --tag nginx-lb