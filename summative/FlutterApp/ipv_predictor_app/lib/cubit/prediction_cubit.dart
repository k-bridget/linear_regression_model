import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/api_service.dart';
import 'prediction_state.dart';

class PredictionCubit extends Cubit<PredictionState> {
  PredictionCubit() : super(const PredictionIdle());

  // Valid values
  static const List<String> validCountries = [
    "Afghanistan",
    "Albania",
    "Angola",
    "Armenia",
    "Azerbaijan",
    "Bangladesh",
    "Benin",
    "Bolivia",
    "Burkina Faso",
    "Burundi",
    "Cambodia",
    "Cameroon",
    "Chad",
    "Colombia",
    "Comoros",
    "Congo",
    "Congo Democratic Republic",
    "Cote d'Ivoire",
    "Dominican Republic",
    "Egypt",
    "Eritrea",
    "Eswatini",
    "Ethiopia",
    "Gabon",
    "Gambia",
    "Ghana",
    "Guatemala",
    "Guinea",
    "Guyana",
    "Haiti",
    "Honduras",
    "India",
    "Indonesia",
    "Jordan",
    "Kenya",
    "Kyrgyz Republic",
    "Lesotho",
    "Liberia",
    "Madagascar",
    "Malawi",
    "Maldives",
    "Mali",
    "Moldova",
    "Morocco",
    "Mozambique",
    "Myanmar",
    "Namibia",
    "Nepal",
    "Nicaragua",
    "Niger",
    "Nigeria",
    "Pakistan",
    "Peru",
    "Philippines",
    "Rwanda",
    "Sao Tome and Principe",
    "Senegal",
    "Sierra Leone",
    "South Africa",
    "Tajikistan",
    "Tanzania",
    "Timor-Leste",
    "Togo",
    "Turkey",
    "Turkmenistan",
    "Uganda",
    "Ukraine",
    "Yemen",
    "Zambia",
    "Zimbabwe",
  ];

  static const List<String> validGenders = ["F", "M"];

  static const List<String> validDemographicsQuestions = [
    "Age",
    "Education",
    "Employment",
    "Marital status",
    "Residence",
  ];

  static const List<String> validDemographicsResponses = [
    "15-24",
    "25-34",
    "35-49",
    "Employed for cash",
    "Employed for kind",
    "Higher",
    "Married or living together",
    "Never married",
    "No education",
    "Primary",
    "Rural",
    "Secondary",
    "Unemployed",
    "Urban",
    "Widowed, divorced, separated",
  ];

  static const List<String> validQuestions = [
    "... for at least one specific reason",
    "... if she argues with him",
    "... if she burns the food",
    "... if she goes out without telling him",
    "... if she neglects the children",
    "... if she refuses to have sex with him",
  ];

  String? _matchValue(String input, List<String> validValues) {
    final trimmed = input.trim();
    for (final valid in validValues) {
      if (valid.toLowerCase() == trimmed.toLowerCase()) return valid;
    }
    return null;
  }

  Future<void> predict({
    required String countryText,
    required String genderText,
    required String demographicsQuestionText,
    required String demographicsResponseText,
    required String questionText,
    required String surveyYearText,
  }) async {
    if (countryText.trim().isEmpty ||
        genderText.trim().isEmpty ||
        demographicsQuestionText.trim().isEmpty ||
        demographicsResponseText.trim().isEmpty ||
        questionText.trim().isEmpty ||
        surveyYearText.trim().isEmpty) {
      emit(const PredictionError('Please fill in all fields.'));
      return;
    }

    final country = _matchValue(countryText, validCountries);
    if (country == null) {
      emit(
        const PredictionError(
          'Unknown country. Please enter a valid DHS survey country, e.g. Kenya, Nigeria, Rwanda.',
        ),
      );
      return;
    }

    final gender = _matchValue(genderText, validGenders);
    if (gender == null) {
      emit(const PredictionError('Gender must be "F" or "M".'));
      return;
    }

    final demographicsQuestion = _matchValue(
      demographicsQuestionText,
      validDemographicsQuestions,
    );
    if (demographicsQuestion == null) {
      emit(
        PredictionError(
          'Demographic dimension must be one of: ${validDemographicsQuestions.join(", ")}.',
        ),
      );
      return;
    }

    final demographicsResponse = _matchValue(
      demographicsResponseText,
      validDemographicsResponses,
    );
    if (demographicsResponse == null) {
      emit(
        PredictionError(
          'Demographic category must be one of: ${validDemographicsResponses.join(", ")}.',
        ),
      );
      return;
    }

    final question = _matchValue(questionText, validQuestions);
    if (question == null) {
      emit(
        PredictionError(
          'Justification question must be one of: ${validQuestions.join(", ")}.',
        ),
      );
      return;
    }

    final surveyYear = int.tryParse(surveyYearText.trim());
    if (surveyYear == null) {
      emit(
        const PredictionError('Survey year must be a whole number, e.g. 2015.'),
      );
      return;
    }
    if (surveyYear < 2000 || surveyYear > 2025) {
      emit(const PredictionError('Survey year must be between 2000 and 2025.'));
      return;
    }

    emit(const PredictionLoading());

    try {
      final result = await ApiService.predictAttitude(
        country: country,
        gender: gender,
        demographicsQuestion: demographicsQuestion,
        demographicsResponse: demographicsResponse,
        question: question,
        surveyYear: surveyYear,
      );

      emit(
        PredictionSuccess(
          predictedValue: (result['predicted_value'] as num).toDouble(),
          country: country,
          question: question,
          surveyYear: surveyYear,
        ),
      );
    } on ApiException catch (e) {
      emit(PredictionError(e.message));
    } catch (e) {
      emit(const PredictionError('Something went wrong. Please try again.'));
    }
  }

  void reset() => emit(const PredictionIdle());
}
