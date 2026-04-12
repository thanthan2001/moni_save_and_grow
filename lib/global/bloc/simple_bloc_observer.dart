import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';

// Lớp này giúp theo dõi (log) tất cả các thay đổi của BLoC trong ứng dụng.
// Rất hữu ích cho việc debug.
class SimpleBlocObserver extends BlocObserver {
  final Logger logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 100,
      printEmojis: false,
    ),
  );

  @override
  void onEvent(Bloc bloc, Object? event) {
    super.onEvent(bloc, event);
    logger.i('onEvent -- ${bloc.runtimeType}, $event');
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    logger.e('onError -- ${bloc.runtimeType}',
        error: error, stackTrace: stackTrace);
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    logger.d(
      'onTransition -- ${bloc.runtimeType}, '
      '${transition.currentState.runtimeType} -> ${transition.nextState.runtimeType}',
    );
  }
}
