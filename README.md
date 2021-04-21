# anpr_dependency

docker build . -t video_processing_framework

docker run -it --rm -v some_folder:/app/home -e DISPLAY=$DISPLAY --gpus all -e QT_X11_NO_MITSHM=1 -v /tmp/.X11-unix:/tmp/.X11-unix image_name /bin/bash