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
    data = extract_data_from_pdf
    raise ExtractionError, "Não foi possível extrair dados do PDF" unless data

    p data.inspect

    prediction = Prediction.new(
      gender:              data['gender'],
      age:                 data['age'].to_i,
      height:              data['height'].to_i,
      weight:              data['weight'].to_f,
      HbA1c_level:         data['HbA1c_level'].to_f,
      blood_glucose_level: data['blood_glucose_level'].to_i,
      hypertension:        data['hypertension'].to_i,
      heart_disease:       data['heart_disease'].to_i,
      smoking_history:     data['smoking_history']
    )

    if prediction.save
      prediction
    else
      raise ExtractionError, prediction.errors.full_messages.join(', ')
    end
  end

  private

  def extract_data_from_pdf
    prompt = <<~PROMPT
      Analise o documento PDF em anexo, que é um relatório de exame de saúde.
      Extraia os seguintes campos e seus respectivos valores.
      Retorne a resposta EXCLUSIVAMENTE em formato JSON, com as chaves em inglês e os valores formatados conforme as regras abaixo:

      Regras de formatação:
      - "gender": 'female' para "Feminino", 'male' para "Masculino".
      - "age": deve ser um número inteiro.
      - "height": deve ser um número inteiro (em cm).
      - "weight": deve ser um número (pode ser decimal, em kg).
      - "HbA1c_level": deve ser um número.
      - "blood_glucose_level": deve ser um número inteiro.
      - "hypertension": 0 para "Não", 1 para "Sim".
      - "heart_disease": 0 para "Não", 1 para "Sim".
      - "smoking_history": 'never' para "Nunca fumou", 'former' para "Ex-fumante", 'current' para "Fumante atual".
    PROMPT

    client = Gemini.new(
      credentials: { service: 'generative-language-api', api_key: Rails.application.credentials.google_api_key },
      options:    { model: 'gemini-2.5-flash' }
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

    Rails.logger.info("[PdfOcrMapper] sending to Gemini…")
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
