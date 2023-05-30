FROM nvcr.io/nvidia/tensorrt:23.04-py3 

ENV DEBIAN_FRONTEND=noninteractive
ENV CUDA_HOME="/usr/local/cuda"
ENV PATH="/usr/local/cuda/bin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH}"
ENV NVIDIA_DRIVER_CAPABILITIES=compute,video,utility
ARG FFMPEG_VERSION=6.0
ARG OPENCV_VERSION="4.7.0"
ARG BASE_DIR='/workspace/'
ARG CUDA_ARCH_BIN="5.3,6.2,7.2,8.7"
ARG ENABLE_NEON="OFF"
ARG FFMPEG_DIR=${BASE_DIR}'/ffmpeg/'
ARG OPENCV_DIR=${BASE_DIR}'/opencv/'
ARG VPF_DIR=${BASE_DIR}'/vpf/'
WORKDIR ${BASE_DIR}
# COPY scripts scripts/
# RUN scripts/install_updates.sh
# RUN scripts/install_ffmpeg.sh



RUN apt-get update
RUN apt-get install -y --no-install-recommends \
        build-essential \
        gfortran \
        cmake \
        git \
        file \
        tar \
        wget \
        unzip \
        libsm6 \
        virtualenv \
        libxext6 \
        iputils-ping \
        libatlas-base-dev \
        libavcodec-dev \
        libavformat-dev \
        libavresample-dev \
        libswresample-dev \
        libavdevice-dev \
        libavfilter-dev \
        libxrender-dev \
        libavutil-dev \
        libcanberra-gtk3-module \
        libdc1394-22-dev \
        libeigen3-dev \
        libglew-dev \
        libgstreamer-plugins-base1.0-dev \
        libgstreamer-plugins-good1.0-dev \
        libgstreamer1.0-dev \
        libgtk-3-dev \
        libjpeg-dev \
        libjpeg8-dev \
        libjpeg-turbo8-dev \
        liblapack-dev \
        liblapacke-dev \
        libopenblas-dev \
        libpng-dev \
        libpostproc-dev \
        libswscale-dev \
        libtbb-dev \
        libtbb2 \
        libtesseract-dev \
        libtiff-dev \
        libv4l-dev \
        libxine2-dev \
        libxvidcore-dev \
        libx264-dev \
        libgtkglext1 \
        libgtkglext1-dev \
        pkg-config \
        qv4l2 \
        v4l-utils \
        zlib1g-dev \
        libtool \
        libc6 \
        libc6-dev \
        libnuma1 \
        libnuma-dev \
        libgl1-mesa-glx \
        x264 \
        software-properties-common \
        libmfx1 \
        libmfx-tools \
        libva-drm2 \
        libva-x11-2 \
        libva-wayland2 \
        libva-glx2 \
        vainfo \
        yasm \
        vim \
        locales \
        less \
        gcc \
        intel-media-va-driver-non-free \
        libva-dev \
        libmfx-dev \
        g++ \
        libbluray-dev \
        libx265-dev \
        libass-dev



# # Installing GPU support for ffmpeg
RUN mkdir -p $FFMPEG_DIR 
WORKDIR ${FFMPEG_DIR}
RUN git clone https://git.videolan.org/git/ffmpeg/nv-codec-headers.git 
RUN cd nv-codec-headers && make install && cd -



# Installing FFMPEG with QSV and Nvidia GPU support
RUN wget https://www.ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.xz && tar xJf ffmpeg-$FFMPEG_VERSION.tar.xz && cd ffmpeg-$FFMPEG_VERSION && ./configure --enable-libmfx --enable-nonfree --enable-libbluray --enable-fontconfig --enable-libass --enable-gpl --enable-libx264 --enable-libx265 --enable-vaapi --enable-cuda-nvcc --enable-libnpp --extra-cflags=-I/usr/local/cuda/include --extra-ldflags=-L/usr/local/cuda/lib64 --disable-static --enable-shared && make -j8 && make install
ENV LIBVA_DRIVER_NAME iHD
ENV LC_ALL C.UTF-8
ENV LANG C.UTF-8
RUN echo "C.UTF-8 UTF-8" >> /etc/locale.gen
RUN locale-gen
# RUN rm -rf $FFMPEG_DIR



RUN ln -s /usr/include/$(uname -i)-linux-gnu/cudnn_version_v8.h /usr/include/$(uname -i)-linux-gnu/cudnn_version.h



# clone and configure OpenCV repo
RUN mkdir -p $OPENCV_DIR
WORKDIR $OPENCV_DIR
RUN echo "Curent Dir: $PWD"
RUN git clone --depth 1 --branch ${OPENCV_VERSION} https://github.com/opencv/opencv.git && \
    git clone --depth 1 --branch ${OPENCV_VERSION} https://github.com/opencv/opencv_contrib.git && \
    cd opencv && \
    mkdir build && \
    cd build && \
    echo "configuring OpenCV ${OPENCV_VERSION}, CUDA_ARCH_BIN=${CUDA_ARCH_BIN}, ENABLE_NEON=${ENABLE_NEON}" && \
    cmake \
        -D CPACK_BINARY_DEB=ON \
	    -D BUILD_EXAMPLES=OFF \
        -D BUILD_opencv_python2=OFF \
        -D BUILD_opencv_python3=ON \
	    -D BUILD_opencv_java=OFF \
        -D CMAKE_BUILD_TYPE=RELEASE \
        -D CMAKE_INSTALL_PREFIX=/usr/local \
        -D CUDA_ARCH_BIN=${CUDA_ARCH_BIN} \
        -D CUDA_ARCH_PTX= \
        -D CUDA_FAST_MATH=ON \
        -D CUDNN_INCLUDE_DIR=/usr/include/$(uname -i)-linux-gnu \
        -D EIGEN_INCLUDE_PATH=/usr/include/eigen3 \
	    -D WITH_EIGEN=ON \
        -D ENABLE_NEON=${ENABLE_NEON} \
        -D OPENCV_DNN_CUDA=ON \
        -D OPENCV_ENABLE_NONFREE=ON \
        -D OPENCV_EXTRA_MODULES_PATH=${OPENCV_DIR}/opencv_contrib/modules \
        -D OPENCV_GENERATE_PKGCONFIG=ON \
        -D PYTHON3_PACKAGES_PATH=/usr/lib/python3/dist-packages \
        -D WITH_CUBLAS=ON \
        -D WITH_CUDA=ON \
        -D WITH_CUDNN=ON \
        -D WITH_GSTREAMER=ON \
        -D WITH_LIBV4L=ON \
        -D WITH_OPENGL=OFF \
        -D WITH_OPENCL=OFF \
        -D WITH_IPP=OFF \
        -D WITH_TBB=ON \
        -D BUILD_TIFF=ON \
        -D BUILD_PERF_TESTS=OFF \
        -D BUILD_TESTS=OFF \
	     ../
	   
RUN cd opencv/build && make -j$(nproc)
# RUN cd opencv/build && make 
RUN cd opencv/build && make install
RUN cd opencv/build && make package
RUN cd opencv/build && tar -czvf OpenCV-${OPENCV_VERSION}-$(uname -i).tar.gz *.deb
# RUN rm -rf $OPENCV_DIR

COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt
RUN rm -rf requirements.txt



RUN git clone  https://github.com/NVIDIA/VideoProcessingFramework.git $VPF_DIR
ADD Video_Codec_SDK_12.1.14.zip $VPF_DIR
ENV CUDACXX /usr/local/cuda/bin/nvcc
RUN cd $VPF_DIR && unzip Video_Codec_SDK_12.1.14.zip && \
    pip3 install . && pip install src/PytorchNvCodec


RUN rm -rf ${BASE_DIR}
WORKDIR '/'
# ENV LD_LIBRARY_PATH=/vpf_app:${LD_LIBRARY_PATH}
CMD ["bash"]

