# Prediction

**Prediction** é um app Ruby on Rails que calcula sua predisposição a desenvolver diabetes tipo 2 usando um modelo de IA treinado no Pima Indians Diabetes Dataset.

## Pré-requisitos

- Ruby 3.x
- Rails 6.x ou 7.x
- PostgreSQL
- Node.js 12+ e Yarn 1+

## Instalação

1. **Clone o repositório**
   ```bash
   git clone https://github.com/Leonardo-Zappani/preferences.git prediction
   cd prediction
   ```

2. **Instale dependências**
   ```bash
   bundle install
   yarn install
   ```

3. **Configure o PostgreSQL**  
   No `config/database.yml`, aponte para seu banco Postgres e depois:
   ```bash
   rails db:create
   rails db:migrate
   ```

4. **(Opcional) Treine o modelo**  
   Se houver script de treino:
   ```bash
   ruby script/train_model.rb
   ```

5. **Inicie o servidor**
   ```bash
   rails server
   ```

## Uso

Na rota principal (`/predictions/new`), preencha:

- `gender: params[:prediction][:gender]`
- `age:    params[:prediction][:age]`
- `weight: params[:prediction][:weight]`
- `height: params[:prediction][:height]`

Clique em **Avaliar** para ver sua probabilidade de risco de diabetes.
