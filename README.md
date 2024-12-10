# gunicorn_vllm
implement multiple vLLM backend via gunicorn to achieve load balance. No need to install docker and nginx.
Thank [UltraEval](https://github.com/OpenBMB/UltraEval)!
use `bash run_vllm.sh` to start.

# requirements
``` bash
gunicorn
gevent
flask
vllm
```