#!/usr/bin/env bash
cd "$(dirname "$0")"
if lsof -iTCP:3000 -sTCP:LISTEN -t >/dev/null; then
  echo "Porta 3000 ocupada. Finalizando o processo..."
  kill -9 $(lsof -iTCP:3000 -sTCP:LISTEN -t)
fi

# Ativa o ambiente virtual
source venv/bin/activate
export PYTHON="$PWD/venv/bin/python"
export PYTHON_LIBRARY="$PWD/venv/lib/libpython3.12.dylib"

# Inicia o servidor Rails
exec bundle exec rails s
