FROM python:3.13-slim

# Create user
RUN useradd -ms /bin/bash puppet
USER puppet

# Set working directory
WORKDIR /home/puppet/work
COPY requirements.txt .
COPY share.py .

# Install dependencies
USER root
RUN apt update && apt install -y --no-install-recommends \
    && pip install --no-cache-dir -r requirements.txt \
    && apt autoremove --purge \
    && apt clean \
    && rm -rf /var/lib/apt/lists/* 

# Run script
# CMD ["ls", "-la"]
CMD ["python", "share.py", "--config", "secrets.json"]
