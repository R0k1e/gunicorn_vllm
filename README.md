# gunicorn_vllm
implement multiple vLLM backend via gunicorn to achieve load balance. No need to install docker and nginx.
Thank [UltraEval](https://github.com/OpenBMB/UltraEval)!
use `bash run_vllm.sh` to start on one node.

use `bash run_all.sh' to start multiple slurm task with daemon.
use `bash scripts/run_docker_daemon.sh` to initialise rootless docker and init docker. Put nginx docker tar in ./nginx_docker/nginx.tar, or directly download nginx:latest image. You must use bash. zsh is not supported
use `bash start_docker.sh` to start nginx daemon.

# requirements
``` bash
gunicorn
gevent
flask
vllm
```