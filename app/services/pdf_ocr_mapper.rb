# app/services/pdf_ocr_mapper.rb

require 'gemini-ai'
require 'base64'
require 'json'

class PdfOcrMapper
  class ExtractionError < StandardError; end

  def initialize(file_content)
    @file_content = file_content
  end

  # Performs OCR+parsing and creates a Prediction record
  # @return [Prediction] the saved record
  # @raise  [ExtractionError] if parsing or save fails
  def call
    data = extract_data_only
    raise ExtractionError, 'Não foi possível extrair dados do PDF' unless data

    p data.inspect

    height = Float(data['height'])
    weight = Float(data['weight'])

    bmi = (weight / (height**2)).round(1)

    Prediction.predict!(
      gender: data['gender'],
      age: data['age'].to_i,
      height: data['height'].to_i,
      weight: data['weight'].to_f,
      HbA1c_level: data['HbA1c_level'].to_f,
      blood_glucose_level: data['blood_glucose_level'].to_i,
      hypertension: data['hypertension'].to_i,
      heart_disease: data['heart_disease'].to_i,
      smoking_history: data['smoking_history'],
      bmi: bmi
    )
  end

  # Performs OCR+parsing and returns extracted data without creating a prediction
  # @return [Hash, nil] the extracted data or nil if extraction fails
  def extract_data_only
    extract_data_from_pdf
  end

  private

  def extract_data_from_pdf
    prompt = <<~PROMPT.freeze
      Você receberá um relatório de exame de saúde em PDF.#{' '}
      Extraia **somente** os campos listados abaixo e devolva um JSON válido – nada mais:

      - gender: "female" para Feminino, "male" para Masculino
      - age: número inteiro
      - height: número inteiro (cm)
      - weight: número (kg; pode ter decimais)
      - HbA1c_level: número (pode ter decimais)
      - blood_glucose_level: número inteiro (mg/dL)
      - hypertension: 0 (Não) ou 1 (Sim)
      - heart_disease: 0 (Não) ou 1 (Sim)
      - smoking_history: "never" | "former" | "current" | "not current" | "ever"

      Exemplo de saída (exatamente neste formato, sem comentários nem markdown):
      {
        "gender": "female",
        "age": 42,
        "height": 170,
        "weight": 68.5,
        "HbA1c_level": 5.7,
        "blood_glucose_level": 130,
        "hypertension": 0,
        "heart_disease": 0,
        "smoking_history": "never"
      }
    PROMPT

    client = Gemini.new(
      credentials: { service: 'generative-language-api', api_key: Rails.application.credentials.google_api_key },
      options: { model: 'gemini-2.5-flash' }
    )

    encoded = Base64.strict_encode64(@file_content)
    body = {   
      contents: [
        {
          role: 'user',
          parts: [
            { text: prompt },
            { inline_data: { mime_type: 'application/pdf', data: encoded } }
          ]
        }
      ]
    }

    Rails.logger.info('[PdfOcrMapper] sending to Gemini…')
    response = client.generate_content(body)
    raw      = response.dig('candidates', 0, 'content', 'parts', 0, 'text')
    return nil unless raw

    json_str = raw
               .gsub(/```json/, '')
               .gsub(/```/, '')
               .strip

    JSON.parse(json_str)
  rescue JSON::ParserError => e
    Rails.logger.error("[PdfOcrMapper] JSON parse failed: #{e.message}")
    nil
  rescue StandardError => e
    Rails.logger.error("[PdfOcrMapper] API call failed: #{e.class} #{e.inspect}")
    nil
  end
end
