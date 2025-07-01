from sklearn.base import BaseEstimator, TransformerMixin
import pandas as pd

class DataFrameTransformer(BaseEstimator, TransformerMixin):
    """
    Converte o array numpy de volta em um DataFrame com colunas nomeadas.
    """
    def __init__(self, feature_names):
        self.feature_names = feature_names

    def fit(self, X, y=None):
        return self

    def transform(self, X):
        return pd.DataFrame(X, columns=self.feature_names)
