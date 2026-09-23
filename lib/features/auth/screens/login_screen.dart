import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../providers/auth_provider.dart';
import '../../../core/widgets/app_icon.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController(text: 'admin');
  final _passwordCtrl = TextEditingController(text: 'admin123');
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).login(
          _usernameCtrl.text,
          _passwordCtrl.text,
        );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(authProvider).error ?? 'Login failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (e) {
          if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.enter) _login();
        },
        child: LayoutBuilder(builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 800;

          Widget formContent = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCompact) ...[
                const AppIcon(AppIcons.localPharmacy, size: 48, color: AppColors.primary),
                const SizedBox(height: 12),
                Text(
                  AppStrings.appName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, fontFamily: 'Poppins'),
                ),
                const SizedBox(height: 20),
              ],
              Text('Welcome back', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text('Sign in to your pharmacy account', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _usernameCtrl,
                      decoration: const InputDecoration(
                        labelText: AppStrings.username,
                        prefixIcon: AppIcon(AppIcons.personOutline),
                      ),
                      validator: (v) => v!.isEmpty ? 'Username required' : null,
                      textInputAction: TextInputAction.next,
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: AppStrings.password,
                        prefixIcon: const AppIcon(AppIcons.lockOutline),
                        suffixIcon: IconButton(
                          icon: AppIcon(_obscurePassword ? AppIcons.visibility : AppIcons.visibilityOff),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) => v!.isEmpty ? 'Password required' : null,
                      onFieldSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: authState.isLoading ? null : _login,
                        child: authState.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Sign In', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Default: admin / admin123',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ),
            ],
          );

          if (isCompact) {
            return Container(
              color: AppColors.surface,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: formContent,
                  ),
                ),
              ),
            );
          }

          return Row(children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryDark, AppColors.primary, AppColors.accent],
                  ),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon(AppIcons.localPharmacy, size: 80, color: Colors.white),
                    SizedBox(height: 24),
                    Text(
                      AppStrings.appName,
                      style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700, fontFamily: 'Poppins'),
                    ),
                    SizedBox(height: 8),
                    Text(
                      AppStrings.tagline,
                      style: TextStyle(color: Colors.white70, fontSize: 15, fontFamily: 'Poppins'),
                    ),
                    SizedBox(height: 48),
                    _FeatureItem(icon: AppIcons.pointOfSale, text: 'Fast POS with thermal printing'),
                    _FeatureItem(icon: AppIcons.inventory2, text: 'Full inventory & batch tracking'),
                    _FeatureItem(icon: AppIcons.sync, text: 'Online / Offline with auto-sync'),
                    _FeatureItem(icon: AppIcons.barChart, text: 'Comprehensive reports & analytics'),
                  ],
                ),
              ),
            ),
            Container(
              width: (constraints.maxWidth * 0.38).clamp(360.0, 480.0),
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
              child: formContent,
            ),
          ]);
        }),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final String icon;
  final String text;
  const _FeatureItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 6),
      child: Row(
        children: [
          AppIcon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 12),
          Flexible(
            child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }
}
