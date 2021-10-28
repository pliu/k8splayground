FROM python:2.7-alpine

ENV PYTHONUNBUFFERED=0

COPY requirements.txt /app/requirements.txt

WORKDIR /app
RUN pip install -r requirements.txt

COPY app.py /app/app.py

ENTRYPOINT ["python", "app.py"]
