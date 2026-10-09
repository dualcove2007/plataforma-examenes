FROM python:3.14-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

# Usuario sin privilegios; las carpetas de escritura se crean antes para
# que el volumen de media herede su propietario.
RUN useradd --create-home --uid 1000 app \
    && mkdir -p /app/media /app/staticfiles \
    && chown -R app:app /app/media /app/staticfiles
USER app

EXPOSE 8000
CMD ["gunicorn", "core.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]