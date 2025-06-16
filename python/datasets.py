from pathlib import Path
import pandas as pd

DATA_DIR = Path(__file__).resolve().parent.parent / "storage" / "data"
DATA_DIR.mkdir(parents=True, exist_ok=True)

def load_kaggle() -> pd.DataFrame:

    csv_path = DATA_DIR / "diabetes_prediction_dataset.csv"
    if not csv_path.exists():
        raise FileNotFoundError(
            f"{csv_path} não encontrado.\n"
            "Coloque o arquivo na pasta acima ou reative o download via Kaggle API."
        )
    return pd.read_csv(csv_path)

def load_nhanes() -> pd.DataFrame:
    return pd.read_csv(DATA_DIR / "nhanes_diabetes.csv")
