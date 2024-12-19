# gunicorn_vllm
implement multiple vLLM backend via gunicorn to achieve load balance. No need to install docker and nginx.
Thank [UltraEval](https://github.com/OpenBMB/UltraEval)!
use `bash run_vllm.sh` to start on one node.

use `bash run_all.sh' to start multiple node via slurm and use nginx as reverse proxy.
You need to run `docker build . -f ./nginx_docker/Dockerfile.nginx --tag nginx-lb` befor use `bash run_all.sh'.

# requirements
```
module load rootless-docker/default
#注意使用bash（不能用zsh）
start_rootless_docker.sh
```
获取 nginx docker

``` bash
gunicorn
gevent
flask
vllm
```