FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN groupadd --system bidbook && useradd --system --gid bidbook --home /app bidbook
WORKDIR /app

COPY pyproject.toml alembic.ini ./
COPY app ./app
COPY migrations ./migrations
RUN pip install --no-cache-dir . && chown -R bidbook:bidbook /app

USER bidbook
EXPOSE 8000

CMD ["sh", "-c", "alembic upgrade head && exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --proxy-headers --forwarded-allow-ips='*'"]
