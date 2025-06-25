#!/usr/bin/env python
"""
Treina um pipeline completo (pre-processamento + HistGradientBoosting)
e salva em storage/models/gbc_final.joblib.

Requisitos:
  pip install pandas scikit-learn joblib
Arquivos esperados:
  storage/data/diabetes_prediction_dataset.csv
  storage/data/nhanes_diabetes.csv
"""

from pathlib import Path
import pandas as pd
import joblib
from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.pipeline import Pipeline
from sklearn.model_selection import train_test_split, GridSearchCV
from sklearn.ensemble import HistGradientBoostingClassifier

# ----------------------------------------------------------------------
# 1. pastas
ROOT      = Path(__file__).resolve().parent.parent
DATA_DIR  = ROOT / "storage" / "data"
MODEL_DIR = ROOT / "storage" / "models"
MODEL_DIR.mkdir(parents=True, exist_ok=True)
MODEL_PATH = MODEL_DIR / "gbc_final.joblib"

# ----------------------------------------------------------------------
# 2. colunas
NUM = ["age", "bmi", "HbA1c_level", "blood_glucose_level"]
CAT = ["gender", "smoking_history", "hypertension", "heart_disease"]

# ----------------------------------------------------------------------
# 3. carregar datasets
def load_csv(name):
    path = DATA_DIR / name
    if not path.exists():
        raise FileNotFoundError(f"{path} não encontrado.")
    return pd.read_csv(path)

def load_data():
    kag = load_csv("diabetes_prediction_dataset.csv"); kag["domain"] = 0
    nh  = load_csv("nhanes_diabetes.csv");             nh["domain"]  = 1
    df  = pd.concat([kag, nh], ignore_index=True)

    # limpa alvo
    df = df[df["diabetes"].notna()]
    df["diabetes"] = pd.to_numeric(df["diabetes"], errors="coerce")
    df = df[df["diabetes"].notna()].copy()
    df["diabetes"] = df["diabetes"].astype(int)
    return df

# ----------------------------------------------------------------------
# 4. treino
def train_and_save():
    df = load_data()
    y = df.pop("diabetes")
    X = df

    X_tr, X_val, y_tr, y_val = train_test_split(
        X, y, test_size=0.2, stratify=y, random_state=42
    )

    pre = ColumnTransformer([
        ("num", StandardScaler(), NUM),
        ("cat", OneHotEncoder(handle_unknown="ignore"), CAT),
    ])

    pipe = Pipeline([
        ("pre", pre),
        ("clf", HistGradientBoostingClassifier(class_weight='balanced')),
    ])

    param_grid = {
        "clf__max_iter":       [200, 400],
        "clf__learning_rate":  [0.05, 0.1],
        "clf__max_leaf_nodes": [31, 63],
    }

    grid = GridSearchCV(
        pipe, param_grid,
        cv=3, scoring="roc_auc", n_jobs=-1, verbose=1
    )
    grid.fit(X_tr, y_tr)

    joblib.dump(grid.best_estimator_, MODEL_PATH, compress=3)
    print(f"✅  Pipeline salvo em {MODEL_PATH}")

if __name__ == "__main__":
    train_and_save()
