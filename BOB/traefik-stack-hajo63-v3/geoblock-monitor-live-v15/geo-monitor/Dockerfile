FROM python:3.12-slim

WORKDIR /app

COPY server.py /app/server.py
COPY static/ /app/static/

ENV PORT=8090
EXPOSE 8090

CMD ["python", "/app/server.py"]
