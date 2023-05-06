FROM nvcr.io/nvidia/tensorrt:22.08-py3

ENV DEBIAN_FRONTEND=noninteractive

ARG FFMPEG_VERSION=5.1.2

WORKDIR /vpf_app

# RUN sed -i 's/archive.ubuntu.com/in.archive.ubuntu.com/g' /etc/apt/sources.list

RUN apt update

RUN apt install -y -q iputils-ping git wget unzip virtualenv build-essential pkg-config libavformat-dev libavcodec-dev libavdevice-dev libavutil-dev libswscale-dev libswresample-dev libavfilter-dev libsm6 libxext6 libxrender-dev libtool libc6 libc6-dev libnuma1 libnuma-dev libgl1-mesa-glx x264 libx264-dev software-properties-common libmfx1 libmfx-tools libva-drm2 libva-x11-2 libva-wayland2 libva-glx2 vainfo yasm vim locales less gcc intel-media-va-driver-non-free libva-dev libmfx-dev g++ libbluray-dev libx264-dev libx265-dev libass-dev

# Installing Latest=3.35.1 cmake required by vpf compilation
ADD https://cmake.org/files/v3.25/cmake-3.25.1-linux-x86_64.sh /cmake-3.25.1-Linux-x86_64.sh
RUN mkdir /opt/cmake
RUN sh /cmake-3.25.1-Linux-x86_64.sh --prefix=/opt/cmake --skip-license
RUN ln -s /opt/cmake/bin/cmake /usr/local/bin/cmake

# Installing GPU support for ffmpeg
RUN git clone https://git.videolan.org/git/ffmpeg/nv-codec-headers.git 
RUN cd nv-codec-headers && make install && cd -

# Installing FFMPEG with QSV support
RUN cd /tmp && wget https://www.ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.xz && tar xJf ffmpeg-$FFMPEG_VERSION.tar.xz && cd ffmpeg-$FFMPEG_VERSION && ./configure --enable-libmfx --enable-nonfree --enable-libbluray --enable-fontconfig --enable-libass --enable-gpl --enable-libx264 --enable-libx265 --enable-vaapi --enable-cuda-nvcc --enable-libnpp --extra-cflags=-I/usr/local/cuda/include --extra-ldflags=-L/usr/local/cuda/lib64 --disable-static --enable-shared && make -j8 && make install
ENV LIBVA_DRIVER_NAME iHD
ENV LC_ALL C.UTF-8
ENV LANG C.UTF-8
RUN echo "C.UTF-8 UTF-8" >> /etc/locale.gen
RUN locale-gen

RUN pip3 install --upgrade pip

RUN pip3 install --no-cache-dir torch torchvision

COPY requirements.txt .

RUN pip3 install --no-cache-dir -r requirements.txt

RUN rm -rf requirements.txt

# Install PyAV with bitstream support
# RUN git clone https://github.com/PyAV-Org/PyAV.git

# RUN cd PyAV && git checkout 44195b6

# RUN /bin/bash -c "cd PyAV && source scripts/activate.sh && pip install --upgrade -r tests/requirements.txt && make"

# RUN cd PyAV && pip3 install .

# Install VPF
# RUN git clone https://github.com/NVIDIA/VideoProcessingFramework.git vpf

# RUN git clone -b master https://github.com/NVIDIA/VideoProcessingFramework.git vpf
RUN git clone  https://github.com/NVIDIA/VideoProcessingFramework.git vpf

ADD Video_Codec_SDK_12.0.16.zip ./vpf

ENV CUDACXX /usr/local/cuda/bin/nvcc

# RUN cd vpf && git checkout f196c99e2e0c918c7b3b780344cb8e75c6654cf0 && unzip Video_Codec_SDK_11.1.5.zip && \
RUN cd vpf && unzip Video_Codec_SDK_12.0.16.zip && \
    pip3 install .
    # mkdir -p build && cd build && \
    # cmake .. \
    #     -DFFMPEG_DIR:PATH="/usr/bin/ffmpeg" \
    #     -DVIDEO_CODEC_SDK_DIR:PATH="/vpf_app/vpf/Video_Codec_SDK_12.0.16" \
    #     -DGENERATE_PYTHON_BINDINGS:BOOL="1" \
    #     -DGENERATE_PYTORCH_EXTENSION:BOOL="0" \
    #     -DPYTHON_LIBRARY=/usr/lib/python3.8/config-3.8-x86_64-linux-gnu/libpython3.8.so \
    #     -DPYTHON_EXECUTABLE="/usr/bin/python3.8" .. \
    #     -DCMAKE_INSTALL_PREFIX:PATH="/vpf_app" && \
    # make -j$(nproc) && make install && \
    # cd /vpf_app && \
    # rm -rf vpf && \
    # mv bin/*.so . && rm -rf bin

ENV LD_LIBRARY_PATH=/vpf_app:${LD_LIBRARY_PATH}

CMD ["bash"]
