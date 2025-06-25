class PredictionError < StandardError
  def initialize(message = "An error occurred during prediction")
    super(message)
  end
end 