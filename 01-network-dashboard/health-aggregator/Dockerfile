# FARCI — health-aggregator (stdlib Python uniquement)
FROM python:3.13-slim-bookworm

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .
COPY config/ ./config/

EXPOSE 8081

CMD ["python", "app.py"]
