# anpr_dependency

docker build . -t sayyam/alpr_dependency:vpf

docker run -it --rm -v some_folder:/app/home -e DISPLAY=$DISPLAY --gpus all -e QT_X11_NO_MITSHM=1 -v /tmp/.X11-unix:/tmp/.X11-unix sayyam/alpr_dependency:vpf /bin/bash