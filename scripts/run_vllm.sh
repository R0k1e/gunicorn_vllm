#!/bin/bash

HF_MODEL_NAME=$1 # huggingface上的模型名
INFER_TYPE=$2
PER_PROC_GPUS=$3
PORT=$4
ENV_NAME=$5

# hyperparameters
# HF_MODEL_NAME="Qwen/Qwen2.5-72B-Instruct"  # huggingface上的模型名
# INFER_TYPE="vLLM"
# CUDA_VISIBLE_DEVICES="4,5,6,7"
# PER_PROC_GPUS=2
# PORT=6324

eval "$(conda shell.bash hook)"
conda activate $ENV_NAME
export LD_LIBRARY_PATH=${HOME}/miniconda3/envs/${ENV_NAME}/lib/python3.11/site-packages/nvidia/nvjitlink/lib:${LD_LIBRARY_PATH}

CUDA_VISIBLE_DEVICES=$(nvidia-smi --query-gpu=index --format=csv,noheader | tr '\n' ',' | sed 's/,$//')

# 步骤2
# 启动 gunicorn 
bash URLs/start_gunicorn.sh --hf-model-name $HF_MODEL_NAME --per-proc-gpus $PER_PROC_GPUS --port $PORT --cuda-visible-devices $CUDA_VISIBLE_DEVICES --infer-type $INFER_TYPE
