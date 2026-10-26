# FARCI — Webhook receiver (stdlib Python uniquement)
ARG PYTHON_IMAGE_TAG
FROM python:${PYTHON_IMAGE_TAG}

WORKDIR /app

COPY webhook.py .

ENV WEBHOOK_SECRET=""
ENV GITOPS_SCRIPT="/app/gitops/gitops.sh"
ENV WEBHOOK_PORT="9000"

EXPOSE 9000

CMD ["python", "webhook.py"]
