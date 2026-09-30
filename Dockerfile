FROM python:3.12-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1

WORKDIR /app

# System dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    unzip \
    libsndfile1 \
    libportaudio2 \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Upgrade packaging tools
RUN python -m pip install --upgrade \
    pip \
    setuptools \
    wheel

# Copy CPU requirements first for Docker cache
COPY requirments_cpu_py312.txt .

# Replace mirrors with official indexes
RUN sed -i \
    's|https://mirrors.pku.edu.cn/pypi/simple|https://pypi.org/simple|g; \
     s|https://mirrors.nju.edu.cn/pytorch/whl/cpu|https://download.pytorch.org/whl/cpu|g' \
    requirments_cpu_py312.txt

# Install CPU dependencies
RUN python -m pip install \
    -r requirments_cpu_py312.txt

# Copy RVC project
COPY . .

# Runtime directories
RUN mkdir -p \
    assets/hubert_base \
    assets/rmvpe \
    assets/pretrained \
    assets/pretrained_v2 \
    assets/pymss_weights \
    assets/weights \
    assets/indices \
    logs/mute \
    datasets \
    .model-downloads

# Hugging Face CLI
RUN python -m pip install --upgrade huggingface_hub

# HuBERT
RUN hf download lj1995/VoiceConversionWebUI \
    --revision main \
    --include "hubert_base/*" \
    --local-dir assets

# RMVPE
RUN hf download lj1995/VoiceConversionWebUI \
    rmvpe.pt \
    --revision main \
    --local-dir assets/rmvpe

# Pretrained RVC models
RUN hf download lj1995/VoiceConversionWebUI \
    --revision main \
    --include "pretrained/*" \
    --include "pretrained_v2/*" \
    --local-dir assets

# Training silence samples
RUN hf download lj1995/VoiceConversionWebUI \
    mute.zip \
    --revision main \
    --local-dir .model-downloads \
    && python -m zipfile -e .model-downloads/mute.zip logs \
    && rm -f .model-downloads/mute.zip

EXPOSE 7865

CMD ["python", "webui.py", "--noautoopen"]