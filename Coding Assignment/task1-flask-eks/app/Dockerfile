# ---- Build stage ----
FROM python:3.12-slim AS builder

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# ---- Runtime stage ----
FROM python:3.12-slim

# Run as non-root user
RUN addgroup --system app && adduser --system --ingroup app app

WORKDIR /app
COPY --from=builder /root/.local /home/app/.local
COPY . .

ENV PATH=/home/app/.local/bin:$PATH \
    PYTHONUNBUFFERED=1

USER app

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/healthz')" || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
