#!/usr/bin/env python
"""
Treina um pipeline completo: feature-engineering, imputação, encoding (OneHot), LightGBM, e ThresholdClassifier.
Faz otimização de hiperparâmetros com Optuna e salva o pipeline em storage/models/gbm_optuna.joblib.
Gera também storage/models/metrics.json.
"""
from pathlib import Path
import json
import joblib
import optuna
import numpy as np
import pandas as pd

from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.pipeline import Pipeline
from sklearn.model_selection import train_test_split, StratifiedKFold
from sklearn.metrics import (
    f1_score,
    precision_recall_curve,
    accuracy_score, precision_score, recall_score
)
from lightgbm import LGBMClassifier

from threshold_classifier import ThresholdClassifier

# ── Configurações ────────────────────────────────────────────────────────
ROOT         = Path(__file__).resolve().parent.parent
DATA_DIR     = ROOT / "storage" / "data"
MODEL_DIR    = ROOT / "storage" / "models"
MODEL_DIR.mkdir(parents=True, exist_ok=True)

PIPE_PATH    = MODEL_DIR / "gbm_optuna.joblib"
METRICS_PATH = MODEL_DIR / "metrics.json"

# 8 colunas originais que queremos usar
NUM_ORIG = ["age", "bmi", "HbA1c_level", "blood_glucose_level"]
CAT_ORIG = ["gender", "smoking_history", "hypertension", "heart_disease"]
# 3 colunas derivadas
DERIVED = ["age_bmi", "bmi_cat", "risk_count"]

# Para o ColumnTransformer:
NUM_FEATS = NUM_ORIG + ["age_bmi", "risk_count"]
CAT_FEATS = CAT_ORIG + ["bmi_cat"]


def load_and_select():
    # Carrega e concatena
    kag = pd.read_csv(DATA_DIR / "diabetes_prediction_dataset.csv"); kag["domain"]=0
    nh  = pd.read_csv(DATA_DIR / "nhanes_diabetes.csv");             nh["domain"]=1
    df  = pd.concat([kag, nh], ignore_index=True)

    # Filtra e converte target
    df = df[df["diabetes"].notna()].copy()
    df["diabetes"] = df["diabetes"].astype(int)

    # Cria features derivadas
    df["age_bmi"]    = df["age"] * df["bmi"]
    df["bmi_cat"]    = pd.cut(
        df["bmi"],
        bins=[0, 18.5, 25, 30, np.inf],
        labels=["under", "normal", "over", "obese"],
    )
    df["risk_count"] = (
        df[["hypertension","heart_disease"]].sum(axis=1)
        + (df["smoking_history"].fillna("never") != "never").astype(int)
    )

    # Seleciona apenas as colunas que vamos usar
    cols = NUM_ORIG + CAT_ORIG + DERIVED + ["diabetes"]
    return df[cols].copy()


def objective(trial, X, y):
    params = {
        "n_estimators":      trial.suggest_int("n_estimators", 400, 1200),
        "learning_rate":     trial.suggest_float("learning_rate", 0.01, 0.2, log=True),
        "max_depth":         trial.suggest_int("max_depth", 3, 8),
        "num_leaves":        trial.suggest_int("num_leaves", 15, 63),
        "min_child_samples": trial.suggest_int("min_child_samples", 20, 100),
        "subsample":         trial.suggest_float("subsample", 0.6, 1.0),
        "colsample_bytree":  trial.suggest_float("colsample_bytree", 0.6, 1.0),
        "class_weight":      "balanced",
        "objective":         "binary",
        "random_state":      42,
        "verbosity":         -1,
    }
    cv = StratifiedKFold(n_splits=3, shuffle=True, random_state=42)
    f1s = []
    for tr_i, va_i in cv.split(X, y):
        m = LGBMClassifier(**params)
        m.fit(X[tr_i], y[tr_i])
        preds = m.predict(X[va_i])
        f1s.append(f1_score(y[va_i], preds))
    return -np.mean(f1s)


def train():
    df = load_and_select()
    y  = df.pop("diabetes")
    X  = df

    # Split
    X_tr, X_val, y_tr, y_val = train_test_split(
        X, y, test_size=0.2, stratify=y, random_state=42
    )

    # Pré-processador: escala numéricas e one-hot em categóricas
    pre = ColumnTransformer([
        ("num", StandardScaler(), NUM_FEATS),
        ("cat", OneHotEncoder(handle_unknown="ignore"), CAT_FEATS),
    ], remainder="drop")

    # Transforma para arrays numéricos antes do Optuna
    X_tr_pre = pre.fit_transform(X_tr)
    X_val_pre = pre.transform(X_val)

    # Optuna
    study = optuna.create_study(direction="minimize")
    study.optimize(lambda t: objective(t, X_tr_pre, y_tr.values), n_trials=40, timeout=1800)

    best_params = study.best_trial.params
    best_params.update({
        "class_weight": "balanced",
        "objective":    "binary",
        "random_state": 42,
        "verbosity":   -1,
    })

    # Treina o modelo final
    clf = LGBMClassifier(**best_params)
    clf.fit(X_tr_pre, y_tr)

    # Determina threshold ótimo
    proba_val = clf.predict_proba(X_val_pre)[:,1]
    prec, rec, thr = precision_recall_curve(y_val, proba_val)
    f1s = 2*prec*rec/(prec+rec+1e-12)
    idx = f1s.argmax()
    best_thr = float(thr[idx])

    # Pipeline final: pre → threshold
    final_pipe = Pipeline([
        ("pre",    pre),
        ("thresh", ThresholdClassifier(estimator=clf, threshold=best_thr)),
    ])

    # Salva pipeline e métricas
    joblib.dump(final_pipe, PIPE_PATH, compress=3)
    print(f"✅ Pipeline salvo em {PIPE_PATH}")

    y_pred = (proba_val >= best_thr).astype(int)
    metrics = {
        "accuracy":           accuracy_score(y_val, y_pred),
        "precision":          precision_score(y_val, y_pred, zero_division=0),
        "recall":             recall_score(y_val, y_pred, zero_division=0),
        "f1_score":           f1s[idx],
        "total_predictions":  int(len(y_val)),
        "correct_predictions":int((y_pred==y_val).sum()),
        "best_threshold":     best_thr
    }
    with open(METRICS_PATH, "w") as fp:
        json.dump(metrics, fp, indent=2)
    print(f"✅ Métricas salvas em {METRICS_PATH}")


if __name__ == "__main__":
    train()
