FROM nvcr.io/nvidia/tensorrt:21.05-py3

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /vpf_app

# RUN sed -i 's/archive.ubuntu.com/in.archive.ubuntu.com/g' /etc/apt/sources.list

RUN apt update

RUN apt install -y git cmake wget unzip ffmpeg virtualenv build-essential pkg-config libavformat-dev libavcodec-dev libavdevice-dev libavutil-dev libswscale-dev libswresample-dev libavfilter-dev libsm6 libxext6 libxrender-dev libtool libc6 libc6-dev libnuma1 libnuma-dev libgl1-mesa-glx x264 libx264-dev

# Install PyAV with bitstream support
RUN git clone https://github.com/PyAV-Org/PyAV.git

RUN cd PyAV && git checkout 44195b6

RUN /bin/bash -c "cd PyAV && source scripts/activate.sh && pip install --upgrade -r tests/requirements.txt && make"

RUN cd PyAV && pip3 install .

# Install VPF
RUN git clone https://github.com/NVIDIA/VideoProcessingFramework.git vpf

ADD Video_Codec_SDK_11.0.10.zip ./vpf

ENV CUDACXX /usr/local/cuda/bin/nvcc

RUN cd vpf && unzip Video_Codec_SDK_11.0.10.zip && \
    mkdir -p build && cd build && \
    cmake .. \
        -DFFMPEG_DIR:PATH="/usr/bin/ffmpeg" \
        -DVIDEO_CODEC_SDK_DIR:PATH="/vpf_app/vpf/Video_Codec_SDK_11.0.10" \
        -DGENERATE_PYTHON_BINDINGS:BOOL="1" \
        -DGENERATE_PYTORCH_EXTENSION:BOOL="0" \
        -DPYTHON_LIBRARY=/usr/lib/python3.8/config-3.8-x86_64-linux-gnu/libpython3.8.so \
        -DPYTHON_EXECUTABLE="/usr/bin/python3.8" .. \
        -DCMAKE_INSTALL_PREFIX:PATH="/vpf_app" && \
    make -j$(nproc) && make install && \
    cd /vpf_app && \
    rm -rf vpf && \
    mv bin/*.so . && rm -rf bin

ENV LD_LIBRARY_PATH=/vpf_app:${LD_LIBRARY_PATH}

COPY requirements.txt .

RUN pip install -r requirements.txt

RUN rm -rf requirements.txt

RUN pip3 install torch==1.8.1+cu111 torchvision==0.9.1+cu111 torchaudio==0.8.1 -f https://download.pytorch.org/whl/torch_stable.html

CMD ["bash"]
