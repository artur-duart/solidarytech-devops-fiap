FROM python:3.14.10-slim-trixie AS builder
ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install -r requirements.txt \
    && pip uninstall -y pip

FROM python:3.14.10-slim-trixie
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

RUN rm -rf /usr/local/bin/pip* /usr/local/lib/python3.14/site-packages/pip* \
    && useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin appuser

COPY --from=builder /opt/venv /opt/venv
WORKDIR /app
COPY --chown=10001:10001 app.py .
USER 10001

HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8083/health')"

EXPOSE 8083
CMD ["gunicorn", "--bind", "0.0.0.0:8083", "--workers", "2", "--access-logfile", "-", "app:app"]
