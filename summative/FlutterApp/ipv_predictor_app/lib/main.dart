import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'cubit/prediction_cubit.dart';
import 'cubit/prediction_state.dart';

void main() {
  runApp(const IpvAttitudeApp());
}

class IpvAttitudeApp extends StatelessWidget {
  const IpvAttitudeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IPV Attitude Predictor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6A1B9A),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
        ),
      ),
      home: BlocProvider(
        create: (_) => PredictionCubit(),
        child: const PredictionPage(),
      ),
    );
  }
}

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  final _countryController = TextEditingController();
  final _genderController = TextEditingController();
  final _demographicsQuestionController = TextEditingController();
  final _demographicsResponseController = TextEditingController();
  final _questionController = TextEditingController();
  final _surveyYearController = TextEditingController();

  @override
  void dispose() {
    _countryController.dispose();
    _genderController.dispose();
    _demographicsQuestionController.dispose();
    _demographicsResponseController.dispose();
    _questionController.dispose();
    _surveyYearController.dispose();
    super.dispose();
  }

  void _onPredictPressed() {
    FocusScope.of(context).unfocus();
    context.read<PredictionCubit>().predict(
      countryText: _countryController.text,
      genderText: _genderController.text,
      demographicsQuestionText: _demographicsQuestionController.text,
      demographicsResponseText: _demographicsResponseController.text,
      questionText: _questionController.text,
      surveyYearText: _surveyYearController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IPV Attitude Predictor'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Predicts the % of a demographic group expected to agree that '
                'intimate partner violence is justified, based on DHS survey data.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _countryController,
                decoration: const InputDecoration(
                  labelText: 'Country',
                  hintText: 'e.g. Rwanda',
                  prefixIcon: Icon(Icons.public),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _genderController,
                decoration: const InputDecoration(
                  labelText: 'Gender (F or M)',
                  hintText: 'e.g. F',
                  prefixIcon: Icon(Icons.person),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _demographicsQuestionController,
                decoration: const InputDecoration(
                  labelText: 'Demographic Dimension',
                  hintText: 'e.g. Education',
                  prefixIcon: Icon(Icons.groups),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _demographicsResponseController,
                decoration: const InputDecoration(
                  labelText: 'Demographic Category',
                  hintText: 'e.g. Higher',
                  prefixIcon: Icon(Icons.category),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _questionController,
                decoration: const InputDecoration(
                  labelText: 'Justification Question',
                  hintText: 'e.g. ... if she burns the food',
                  prefixIcon: Icon(Icons.help_outline),
                ),
                textInputAction: TextInputAction.next,
                maxLines: 2,
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _surveyYearController,
                decoration: const InputDecoration(
                  labelText: 'Survey Year',
                  hintText: 'e.g. 2015',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 24),

              BlocBuilder<PredictionCubit, PredictionState>(
                builder: (context, state) {
                  final isLoading = state is PredictionLoading;
                  return FilledButton.icon(
                    onPressed: isLoading ? null : _onPredictPressed,
                    icon: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.analytics),
                    label: Text(isLoading ? 'Predicting...' : 'Predict'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              BlocBuilder<PredictionCubit, PredictionState>(
                builder: (context, state) => _ResultDisplay(state: state),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultDisplay extends StatelessWidget {
  final PredictionState state;
  const _ResultDisplay({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state is PredictionIdle || state is PredictionLoading) {
      return const SizedBox.shrink();
    }

    if (state is PredictionError) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                (state as PredictionError).message,
                style: TextStyle(color: Colors.red.shade900),
              ),
            ),
          ],
        ),
      );
    }

    final result = state as PredictionSuccess;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        border: Border.all(color: Colors.purple.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Predicted Agreement',
            style: TextStyle(
              color: Colors.purple.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${result.predictedValue.toStringAsFixed(1)}%',
            style: TextStyle(
              color: Colors.purple.shade900,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${result.country} · ${result.surveyYear}',
            style: TextStyle(color: Colors.purple.shade700, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            result.question,
            style: TextStyle(
              color: Colors.purple.shade700,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
