From nvcr.io/nvidia/tensorrt:20.09-py3
# RUN apt-get update && apt-get install libgl1-mesa-glx -y
COPY run.sh .
COPY requirements.txt .
# RUN chmod +x script.sh
RUN ./run.sh
CMD ["bash"]