import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/auth_controller.dart';
import '../shared/layout.dart';
import '../shared/side_navigation.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.onCreateAccount,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final VoidCallback onCreateAccount;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final auth = context.read<AuthController>();
    final ok = await auth.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    // On success FlorgApp switches screens on its own by listening to the
    // AuthController, so only the failure path needs handling here.
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Nao foi possivel entrar.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 940;
            final padding = EdgeInsets.all(isWide ? 32 : 20);

            return SingleChildScrollView(
              padding: padding,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(
                    0.0,
                    constraints.maxHeight - padding.vertical,
                  ),
                ),
                child: isWide
                    ? Row(
                        children: [
                          const Expanded(child: LoginShowcase()),
                          const SizedBox(width: 40),
                          SizedBox(width: 420, child: _buildLoginCard()),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const LoginShowcase(isCompact: true),
                          const SizedBox(height: 24),
                          _buildLoginCard(),
                        ],
                      ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    // Swaps the button for a spinner during the call, preventing a double
    // submit.
    final isSubmitting = context.watch<AuthController>().isSubmitting;
    return AppCard(
      padding: const EdgeInsets.all(28),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const LeafLogo(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Entrar no FLORG',
                          style: TextStyle(
                            color: AppColors.primaryText(context),
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Acesse sua area financeira.',
                          style: TextStyle(
                            color: AppColors.secondaryText(context),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ThemeIconButton(
                    isDarkMode: widget.isDarkMode,
                    onPressed: widget.onToggleTheme,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: _fieldDecoration(
                  context,
                  label: 'E-mail',
                  icon: Icons.mail_rounded,
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) {
                    return 'Informe seu e-mail.';
                  }
                  if (!email.contains('@') || !email.contains('.')) {
                    return 'Use um e-mail valido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                decoration: _fieldDecoration(
                  context,
                  label: 'Senha',
                  icon: Icons.lock_rounded,
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Mostrar senha'
                        : 'Ocultar senha',
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                    ),
                  ),
                ),
                validator: (value) {
                  if ((value ?? '').length < 6) {
                    return 'Use ao menos 6 caracteres.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _rememberMe = !_rememberMe),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() => _rememberMe = value ?? false);
                          },
                        ),
                        Text(
                          'Manter conectado',
                          style: TextStyle(
                            color: AppColors.secondaryText(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Esqueci minha senha'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: isSubmitting
                    ? const SizedBox(
                        height: 50,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : GradientButton(
                        label: 'Entrar',
                        icon: Icons.login_rounded,
                        onPressed: _submit,
                        height: 50,
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Ainda nao tem conta?',
                    style: TextStyle(color: AppColors.secondaryText(context)),
                  ),
                  TextButton(
                    onPressed: isSubmitting ? null : widget.onCreateAccount,
                    child: const Text('Criar conta'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.inputFill(context),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.accentText(context), width: 2),
      ),
    );
  }
}

class LoginShowcase extends StatelessWidget {
  const LoginShowcase({super.key, this.isCompact = false});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      gradient: tealEmeraldGradient,
      borderColor: null,
      padding: EdgeInsets.all(isCompact ? 22 : 32),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                const LeafLogo(size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'FLORG',
                    style: TextStyle(
                      fontSize: isCompact ? 26 : 34,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'Sua vida financeira em ordem.',
              style: TextStyle(
                fontSize: isCompact ? 28 : 44,
                fontWeight: FontWeight.w700,
                height: 1.08,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeIconButton extends StatelessWidget {
  const _ThemeIconButton({required this.isDarkMode, required this.onPressed});

  final bool isDarkMode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: isDarkMode ? 'Modo claro' : 'Modo escuro',
      onPressed: onPressed,
      icon: Icon(
        isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
      ),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.subtleFill(context),
        foregroundColor: AppColors.accentText(context),
      ),
    );
  }
}
