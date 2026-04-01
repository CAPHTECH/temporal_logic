import 'package:flutter/widgets.dart';

/// Shared lifecycle and builder helpers for temporal logic widgets.
abstract class CheckerWidgetStateBase<W extends StatefulWidget, Result>
    extends State<W> {
  late Result initialResult;

  @protected
  Result calculateInitialResult();

  @protected
  void initializeChecker();

  @protected
  void disposeChecker();

  @protected
  bool shouldRecreateChecker(covariant W oldWidget);

  @protected
  Widget buildResultStream({
    required Key key,
    required Stream<Result> stream,
    required Widget Function(BuildContext context, Result result) builder,
  }) {
    return StreamBuilder<Result>(
      key: key,
      initialData: initialResult,
      stream: stream,
      builder: (context, snapshot) {
        final result = snapshot.data ?? initialResult;
        return builder(context, result);
      },
    );
  }

  @override
  @mustCallSuper
  void initState() {
    super.initState();
    initialResult = calculateInitialResult();
    initializeChecker();
  }

  @override
  @mustCallSuper
  void didUpdateWidget(covariant W oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (shouldRecreateChecker(oldWidget)) {
      disposeChecker();
      initialResult = calculateInitialResult();
      initializeChecker();
    }
  }

  @override
  @mustCallSuper
  void dispose() {
    disposeChecker();
    super.dispose();
  }
}
