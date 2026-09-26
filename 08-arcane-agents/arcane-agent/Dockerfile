# FARCI — Agent Arcane (stdlib Python uniquement)
FROM python:3.13-slim-bookworm

WORKDIR /app

COPY agent.py .
COPY config.yaml .

ENV TARGET_SERVICE=""
ENV TARGET_URL=""
ENV CHECK_INTERVAL="30"
ENV ALERT_WEBHOOK=""

CMD ["python", "agent.py"]
