import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- State Definition ---

enum AppScreen { login, loading, home, error }

@immutable
class AppState {
  final AppScreen currentScreen;
  final String email;
  final String errorMessage;
  // Flag to indicate the login *event* just occurred for LTL.
  // This should ideally be transient or handled differently in production,
  // but is simple for this example.
  final bool loginAttempted;

  const AppState({
    this.currentScreen = AppScreen.login,
    this.email = '',
    this.errorMessage = '',
    this.loginAttempted = false,
  });

  AppState copyWith({
    AppScreen? currentScreen,
    String? email,
    String? errorMessage,
    bool? loginAttempted,
    bool clearError = false, // Helper to clear error on state change
    bool clearLoginAttempt = false, // Helper to reset event flag
  }) {
    return AppState(
      currentScreen: currentScreen ?? this.currentScreen,
      email: email ?? this.email,
      errorMessage: clearError ? '' : errorMessage ?? this.errorMessage,
      loginAttempted: clearLoginAttempt ? false : loginAttempted ?? this.loginAttempted,
    );
  }
}

// --- State Snapshot for Temporal Logic ---

// Represents the state captured at a point in time for the trace.
@immutable
class AppSnap {
  final bool isLoading;
  final bool isOnHomeScreen;
  final bool hasError;
  final bool loginClicked; // Captures the event flag

  const AppSnap({
    required this.isLoading,
    required this.isOnHomeScreen,
    required this.hasError,
    required this.loginClicked,
  });

  // Factory to create a snapshot from the main AppState
  factory AppSnap.fromAppState(AppState state) {
    return AppSnap(
      isLoading: state.currentScreen == AppScreen.loading,
      isOnHomeScreen: state.currentScreen == AppScreen.home,
      hasError: state.currentScreen == AppScreen.error || state.errorMessage.isNotEmpty,
      loginClicked: state.loginAttempted,
    );
  }

  @override
  String toString() {
    return 'AppSnap(loading: $isLoading, home: $isOnHomeScreen, error: $hasError, clicked: $loginClicked)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSnap &&
          runtimeType == other.runtimeType &&
          isLoading == other.isLoading &&
          isOnHomeScreen == other.isOnHomeScreen &&
          hasError == other.hasError &&
          loginClicked == other.loginClicked;

  @override
  int get hashCode => isLoading.hashCode ^ isOnHomeScreen.hashCode ^ hasError.hashCode ^ loginClicked.hashCode;
}

// --- State Management (Riverpod) ---

class AppStateNotifier extends StateNotifier<AppState> {
  // Recorder is no longer passed in or used here
  AppStateNotifier() : super(const AppState());

  void updateEmail(String email) {
    state = state.copyWith(email: email);
  }

  Future<void> login() async {
    // 1. Set loginAttempted flag and move to loading
    state = state.copyWith(loginAttempted: true, currentScreen: AppScreen.loading, clearError: true);

    // Reset the transient event flag immediately after recording it
    state = state.copyWith(clearLoginAttempt: true);

    // Simulate network request
    await Future.delayed(const Duration(seconds: 1));

    // Simulate success/failure based on email
    if (state.email.contains('@') && state.email.length > 3) {
      // *** BUG SIMULATION: Flicker to error state before home ***
      state = state.copyWith(currentScreen: AppScreen.error, errorMessage: 'Temporary Flicker!');
      // Add a small delay to ensure the state change is potentially recorded
      await Future.delayed(const Duration(milliseconds: 50));
      // *** End Bug Simulation ***

      state = state.copyWith(currentScreen: AppScreen.home, clearError: true); // Go to home
    } else {
      state = state.copyWith(currentScreen: AppScreen.error, errorMessage: 'Invalid email format.');
    }
  }

  void logout() {
    state = const AppState(); // Reset to initial state
  }
}

final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  // No longer needs the recorder
  return AppStateNotifier();
});

// --- UI ---

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screen = ref.watch(appStateProvider.select((s) => s.currentScreen));

    Widget body;
    switch (screen) {
      case AppScreen.login:
        body = const LoginScreen();
        break;
      case AppScreen.loading:
        body = const LoadingScreen();
        break;
      case AppScreen.home:
        body = const HomeScreen();
        break;
      case AppScreen.error:
        body = const ErrorScreen();
        break;
    }

    return MaterialApp(
      title: 'Login LTL Example',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Login LTL Example'),
        ),
        body: Center(child: body),
      ),
    );
  }
}

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(appStateProvider.notifier);
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            key: const Key('email'),
            onChanged: notifier.updateEmail,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            key: const Key('login'),
            onPressed: notifier.login,
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CircularProgressIndicator();
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(appStateProvider.notifier);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Welcome Home!', style: TextStyle(fontSize: 24)),
        const SizedBox(height: 20),
        ElevatedButton(
          key: const Key('logout'),
          onPressed: notifier.logout,
          child: const Text('Logout'),
        ),
      ],
    );
  }
}

class ErrorScreen extends ConsumerWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final errorMessage = ref.watch(appStateProvider.select((s) => s.errorMessage));
    final notifier = ref.read(appStateProvider.notifier);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Error: $errorMessage', style: const TextStyle(color: Colors.red, fontSize: 18)),
        const SizedBox(height: 20),
        ElevatedButton(
          key: const Key('back_to_login'),
          onPressed: notifier.logout, // Go back to login screen
          child: const Text('Try Again'),
        ),
      ],
    );
  }
}
