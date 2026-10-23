# FARCI — Agent Arcane (stdlib Python uniquement)
ARG PYTHON_IMAGE_TAG
FROM python:${PYTHON_IMAGE_TAG}

WORKDIR /app

COPY agent.py .
COPY config.yaml .

ENV TARGET_SERVICE=""
ENV TARGET_URL=""
ENV CHECK_INTERVAL="30"
ENV ALERT_WEBHOOK=""

CMD ["python", "agent.py"]
