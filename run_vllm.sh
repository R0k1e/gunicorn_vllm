#!/bin/bash

# change this path to your conda env path, to fix the bug /nvidia/cusparse/lib/libcusparse.so.12: undefined symbol: __nvJitLinkComplete_12_4, version libnvJitLink.so.12  
export LD_LIBRARY_PATH=${HOME}/miniconda3/envs/gunicorn/lib/python3.11/site-packages/nvidia/nvjitlink/lib:${LD_LIBRARY_PATH}
# hyperparameters
HF_MODEL_NAME="Qwen/Qwen2.5-72B-Instruct-AWQ"  # huggingface上的模型名
INFER_TYPE="vLLM" 
CUDA_VISIBLE_DEVICES="4,5,6,7"
PER_PROC_GPUS=2
PORT=6324

# 步骤2
# 启动 gunicorn 并保存 PID
bash URLs/start_gunicorn.sh --hf-model-name $HF_MODEL_NAME --per-proc-gpus $PER_PROC_GPUS --port $PORT --cuda-visible-devices $CUDA_VISIBLE_DEVICES --infer-type $INFER_TYPE
echo $! > gunicorn.pid

# 步骤5
# del gunicorn.pid file
# 结束 gunicorn 进程及其 worker 进程
# rm gunicorn.pid
# pkill gunicorn; sleep 5; kill -SIGINT $$