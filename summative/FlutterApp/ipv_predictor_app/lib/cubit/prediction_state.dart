import 'package:equatable/equatable.dart';

abstract class PredictionState extends Equatable {
  const PredictionState();

  @override
  List<Object?> get props => [];
}

/// Initial state, before any prediction has been requested.
class PredictionIdle extends PredictionState {
  const PredictionIdle();
}

/// A prediction request.
class PredictionLoading extends PredictionState {
  const PredictionLoading();
}

/// The API returned a successful prediction.
class PredictionSuccess extends PredictionState {
  final double predictedValue;
  final String country;
  final String question;
  final int surveyYear;

  const PredictionSuccess({
    required this.predictedValue,
    required this.country,
    required this.question,
    required this.surveyYear,
  });

  @override
  List<Object?> get props => [predictedValue, country, question, surveyYear];
}

/// Something went wrong: validation error, network error, or server error.
class PredictionError extends PredictionState {
  final String message;

  const PredictionError(this.message);

  @override
  List<Object?> get props => [message];
}
