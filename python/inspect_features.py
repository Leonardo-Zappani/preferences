#!/usr/bin/env python
import joblib

# Caminho para o pipeline salvo
PIPE_PATH = "../storage/models/gbm_optuna.joblib"

# 1) Carrega o pipeline serializado
pipe = joblib.load(PIPE_PATH)

# 2) Extrai o pré-processador (ColumnTransformer) pelo nome do step
#    Ajuste o nome "pre" se seu Pipeline usar outro nome
pre = pipe.named_steps["pre"]

# 3) Imprime todas as colunas que o ColumnTransformer espera receber
print("Colunas de entrada esperadas pelo ColumnTransformer:")
for col in pre.feature_names_in_:
    print(f" - {col}")
