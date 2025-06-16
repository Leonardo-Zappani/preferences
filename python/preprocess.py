import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import StandardScaler, OneHotEncoder

NUM = ["age", "bmi", "HbA1c_level", "blood_glucose_level"]
CAT = ["gender", "smoking_history", "hypertension", "heart_disease"]

def make_pipeline():
    return ColumnTransformer([
        ("num", StandardScaler(), NUM),
        ("cat", OneHotEncoder(handle_unknown="ignore"), CAT),
    ])

def split_xy(df: pd.DataFrame):
    y = df.pop("diabetes")
    X = make_pipeline().fit_transform(df)
    return X, y
