FROM python:3.12.9-alpine3.21
WORKDIR /app
COPY app/app.py .
EXPOSE 8000
CMD ["python", "app.py"]
