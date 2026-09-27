# FARCI — Webhook receiver (stdlib Python uniquement)
FROM python:3.13-slim-bookworm

WORKDIR /app

COPY webhook.py .

ENV WEBHOOK_SECRET=""
ENV GITOPS_SCRIPT="/app/gitops/gitops.sh"
ENV WEBHOOK_PORT="9000"

EXPOSE 9000

CMD ["python", "webhook.py"]
