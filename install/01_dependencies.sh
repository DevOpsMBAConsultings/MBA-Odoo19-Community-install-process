#!/bin/bash
set -e

echo "Installing system dependencies..."

apt install -y \
  git \
  python3 \
  python3-pip \
  python3-dev \
  python3-venv \
  build-essential \
  libxslt-dev \
  libzip-dev \
  libldap2-dev \
  libsasl2-dev \
  libpq-dev \
  libxml2-dev \
  libjpeg-dev \
  zlib1g-dev \
  libfreetype6-dev \
  liblcms2-dev \
  libblas-dev \
  libatlas-base-dev \
  libffi-dev \
  libssl-dev \
  wkhtmltopdf

echo "Dependencies installed."
