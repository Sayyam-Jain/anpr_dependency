#!/bin/sh
git clone https://github.com/Sayyam-Jain/nv-codec-headers.git --branch sdk/10.0
cd nv-codec-headers && make install && cd ..
git clone https://github.com/Sayyam-Jain/FFmpeg.git && cd FFmpeg
apt-get update && apt-get install -y build-essential yasm cmake libtool libc6 libc6-dev unzip wget libnuma1 libnuma-dev libgl1-mesa-glx x264 libx264-dev
# changing compute_30 to compute_35 and sm_30 to sm_35 inside the ffmpeg/configure worked
# sed "s/compute_30/compute_35/g" >configure
# sed "s/sm_30/sm_35/g" >configure
./configure --enable-nonfree --enable-cuda-sdk --enable-libnpp --extra-cflags=-I/usr/local/cuda/include --extra-ldflags=-L/usr/local/cuda/lib64
make -j 8
make install && cd ..
pip install -r requirements.txt