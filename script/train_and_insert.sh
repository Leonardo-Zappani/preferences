#!/bin/bash

echo "🔄 Iniciando treino do modelo..."
python ../python/train.py

echo "🔄 Inserindo métricas no banco..."
rails runner script/save_model_metrics.rb

echo "✅ Processo concluído!"
