From nvcr.io/nvidia/tensorrt:20.07.1-py3
RUN apt-get update && apt-get install libgl1-mesa-glx -y
COPY requirements.txt .
RUN pip install -r requirements.txt
CMD ["bash"]