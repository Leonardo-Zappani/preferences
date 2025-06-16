#!/usr/bin/env bash
cd "$(dirname "$0")"
source venv/bin/activate
export PYTHON="$PWD/venv/bin/python"
export PYTHON_LIBRARY="$PWD/venv/lib/libpython3.12.dylib"
exec bundle exec rails s
