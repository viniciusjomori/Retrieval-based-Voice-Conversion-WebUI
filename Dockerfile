FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1

WORKDIR /app


# ------------------------------------------------------------
# System dependencies
# ------------------------------------------------------------

RUN apt-get update && apt-get install -y \
    software-properties-common \
    ffmpeg \
    unzip \
    libsndfile1 \
    libportaudio2 \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*


# ------------------------------------------------------------
# Python 3.12
# ------------------------------------------------------------

RUN add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update && \
    apt-get install -y \
        python3.12 \
        python3.12-dev \
        python3.12-venv \
    && rm -rf /var/lib/apt/lists/*

RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.12

RUN python3.12 -m pip install --upgrade \
    pip \
    setuptools \
    wheel


# ------------------------------------------------------------
# Python dependencies
# ------------------------------------------------------------

# Copy requirements first so Docker can cache this layer.
COPY requirments_cu118_py312.txt .


# Install the CUDA 11.8 PyTorch build explicitly.
RUN python3.12 -m pip install \
    torch==2.7.1+cu118 \
    torchaudio==2.7.1+cu118 \
    --index-url https://download.pytorch.org/whl/cu118 \
    --extra-index-url https://pypi.org/simple


# Replace the default Chinese mirrors with official indexes.
RUN sed -i \
    's|https://mirrors.pku.edu.cn/pypi/simple|https://pypi.org/simple|g; \
     s|https://mirrors.nju.edu.cn/pytorch/whl/cu118|https://download.pytorch.org/whl/cu118|g' \
    requirments_cu118_py312.txt


# The upstream requirements currently pin a cuDNN version whose Linux
# wheel is unavailable. Use the compatible available release instead.
RUN sed -i \
    's/nvidia-cudnn-cu11==8.9.5.29/nvidia-cudnn-cu11==8.9.5.30/g' \
    requirments_cu118_py312.txt


RUN python3.12 -m pip install \
    -r requirments_cu118_py312.txt


# ------------------------------------------------------------
# RVC source
# ------------------------------------------------------------

COPY . .


# ------------------------------------------------------------
# Runtime directories
# ------------------------------------------------------------

RUN mkdir -p \
    assets/hubert_base \
    assets/rmvpe \
    assets/pretrained \
    assets/pretrained_v2 \
    assets/pymss_weights \
    assets/weights \
    assets/indices \
    logs/mute \
    .model-downloads


# ------------------------------------------------------------
# Hugging Face
# ------------------------------------------------------------

RUN python3.12 -m pip install --upgrade huggingface_hub


# ------------------------------------------------------------
# Required models: inference / feature extraction
# ------------------------------------------------------------

RUN hf download lj1995/VoiceConversionWebUI \
    --revision main \
    --include "hubert_base/*" \
    --local-dir assets


RUN hf download lj1995/VoiceConversionWebUI \
    rmvpe.pt \
    --revision main \
    --local-dir assets/rmvpe


# ------------------------------------------------------------
# Required models: RVC training
# ------------------------------------------------------------

RUN hf download lj1995/VoiceConversionWebUI \
    --revision main \
    --include "pretrained/*" \
    --include "pretrained_v2/*" \
    --local-dir assets


# ------------------------------------------------------------
# Required silence samples for training
# ------------------------------------------------------------

RUN hf download lj1995/VoiceConversionWebUI \
    mute.zip \
    --revision main \
    --local-dir .model-downloads \
    && python3.12 -m zipfile -e .model-downloads/mute.zip logs \
    && rm -f .model-downloads/mute.zip


# ------------------------------------------------------------
# Optional: pymss/MSST vocal separation models
# ------------------------------------------------------------

RUN hf download lj1995/VoiceConversionWebUI \
    --revision main \
    --include "pymss_weights/*" \
    --local-dir assets


# ------------------------------------------------------------
# WebUI
# ------------------------------------------------------------

EXPOSE 7865

CMD ["python3.12", "webui.py", "--noautoopen"]