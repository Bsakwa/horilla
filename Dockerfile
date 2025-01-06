FROM python:3.10-slim-bullseye
# Set environment variable to ensure output is not buffered
ENV PYTHONUNBUFFERED 1
# Install dependencies for PostgreSQL client tools and others
RUN apt-get update && apt-get install -y \
    libcairo2-dev \
    gcc \
    postgresql-client  # Add PostgreSQL client to use pg_isready and psql
# Set the working directory inside the container
WORKDIR /app/
# Copy all files from the current directory to /app
COPY . .
# Make the entrypoint script executable
RUN chmod +x /app/entrypoint.sh
# Install Python dependencies from requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
# Expose the port that the app will be running on (default Django port)
EXPOSE 8000
# Use the entrypoint script to start the application
ENTRYPOINT ["/app/entrypoint.sh"]
