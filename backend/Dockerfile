FROM python:3.11-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY pyproject.toml /app/pyproject.toml

RUN pip install --no-cache-dir -U pip && \
    pip install --no-cache-dir "fastapi>=0.115" "uvicorn[standard]>=0.30" "sqlalchemy>=2.0" "psycopg[binary]>=3.2" \
      "pydantic>=2.8" "pydantic-settings>=2.4" "email-validator>=2.1" "python-jose[cryptography]>=3.3" "bcrypt>=4.0.1,<5" "python-multipart>=0.0.9" \
      "google-auth>=2.29" "requests>=2.32"

COPY app /app/app

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

