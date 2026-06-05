# syntax=docker/dockerfile:1.7

FROM node:20-bookworm-slim AS dashboard-build

ARG DASHBOARD_REPO=https://github.com/Mianotes/mianotes-dashboard.git
ARG DASHBOARD_REF=main

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates git \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone "$DASHBOARD_REPO" dashboard \
  && git -C dashboard checkout "$DASHBOARD_REF"

WORKDIR /src/dashboard
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi
RUN npm run build

FROM python:3.12-slim-bookworm AS runtime

ARG WEB_SERVICE_REPO=https://github.com/Mianotes/mianotes-web-service.git
ARG WEB_SERVICE_REF=main

ENV PYTHONUNBUFFERED=1 \
  PATH="/opt/mianotes/.venv/bin:$PATH" \
  MIANOTES_HOST=0.0.0.0 \
  MIANOTES_PORT=8200 \
  MIANOTES_DASHBOARD_HOST=0.0.0.0 \
  MIANOTES_DASHBOARD_PORT=8201 \
  MIANOTES_DATA_DIR=/data \
  MIANOTES_STORAGE_CONFIG_PATH=/data/workspaces.json \
  MIANOTES_ENV_FILE=/data/mianotes.env

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    ffmpeg \
    flac \
    git \
    ripgrep \
    tesseract-ocr \
    tesseract-ocr-eng \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/mianotes

RUN git clone "$WEB_SERVICE_REPO" web-service \
  && git -C web-service checkout "$WEB_SERVICE_REF" \
  && python -m venv /opt/mianotes/.venv \
  && /opt/mianotes/.venv/bin/python -m pip install --upgrade pip \
  && /opt/mianotes/.venv/bin/pip install /opt/mianotes/web-service

RUN mkdir -p /opt/mianotes/bin /opt/mianotes/dashboard/dist /data

COPY common/bin/dashboard_server.py /opt/mianotes/bin/dashboard_server.py
COPY docker/entrypoint.sh /opt/mianotes/bin/docker-entrypoint.sh
COPY --from=dashboard-build /src/dashboard/dist/ /opt/mianotes/dashboard/dist/

RUN chmod 755 /opt/mianotes/bin/dashboard_server.py /opt/mianotes/bin/docker-entrypoint.sh

VOLUME ["/data"]
EXPOSE 8200 8201

ENTRYPOINT ["/opt/mianotes/bin/docker-entrypoint.sh"]
