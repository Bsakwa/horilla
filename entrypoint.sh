#!/bin/bash

# Exit on error
set -e

# Function to wait for postgres to be ready
wait_for_postgres() {
    echo "Waiting for postgres..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if pg_isready -h db -p 5432 -U postgres; then
            echo "Postgres is up - executing command"
            return 0
        fi
        
        echo "Postgres is unavailable - sleeping (attempt $attempt/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "Failed to connect to Postgres after $max_attempts attempts"
    return 1
}

# Function to create superuser
create_superuser() {
    echo "Creating superuser..."
    python3 manage.py createhorillauser \
        --first_name admin \
        --last_name admin \
        --username admin \
        --password admin \
        --email admin@example.com \
        --phone 1234567890 || {
            echo "Superuser already exists or creation failed (this is normal if user exists)"
        }
}

# Function to check database connection
check_database_connection() {
    local max_retries=5
    local retry=0
    local wait_time=5

    while [ $retry -lt $max_retries ]; do
        if python3 manage.py check --database default > /dev/null 2>&1; then
            echo "Database connection successful"
            return 0
        fi
        echo "Database connection failed, retrying in $wait_time seconds... ($(( retry + 1 ))/$max_retries)"
        sleep $wait_time
        retry=$(( retry + 1 ))
    done

    echo "Failed to establish database connection after $max_retries attempts"
    return 1
}

echo "Starting database setup..."

# Wait for postgres
wait_for_postgres

# Check database connection
check_database_connection

# Apply database migrations
echo "Applying database migrations..."
python3 manage.py makemigrations --noinput
python3 manage.py migrate --noinput

# Collect static files
echo "Collecting static files..."
python3 manage.py collectstatic --noinput

# Create superuser
create_superuser

# Start Gunicorn with optimized settings
echo "Starting Gunicorn..."
exec gunicorn --bind 0.0.0.0:8000 \
    --workers 3 \
    --threads 2 \
    --worker-class=gthread \
    --timeout 120 \
    --keep-alive 5 \
    --max-requests 1000 \
    --max-requests-jitter 50 \
    --access-logfile - \
    --error-logfile - \
    --log-level info \
    --capture-output \
    horilla.wsgi:application
