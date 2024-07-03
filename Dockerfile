FROM alloranetwork/allora-inference-base:latest

RUN pip install python-okx requests

COPY main.py /app/