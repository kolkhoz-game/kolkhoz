part of 'settings_view.dart';

enum _CloudAuthAction { signIn, resetPassword, signUp }

class CloudAuthView extends StatefulWidget {
  const CloudAuthView({
    super.key,
    required this.tokens,
    required this.language,
    required this.configured,
    required this.ready,
    required this.busy,
    required this.message,
    required this.messageIsError,
    required this.onSignIn,
    required this.onSignUp,
    required this.onResetPassword,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final bool configured;
  final bool ready;
  final bool busy;
  final String? message;
  final bool messageIsError;
  final Future<void> Function(String email, String password)? onSignIn;
  final Future<void> Function(String email, String password)? onSignUp;
  final Future<void> Function(String email)? onResetPassword;

  @override
  State<CloudAuthView> createState() => _CloudAuthPanelState();
}

class _CloudAuthPanelState extends State<CloudAuthView> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController emailController;
  late final TextEditingController passwordController;
  late final TextEditingController confirmPasswordController;
  String? localMessage;
  _CloudAuthAction validationAction = _CloudAuthAction.signIn;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController();
    passwordController = TextEditingController();
    confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void clearLocalMessage() {
    if (localMessage == null) {
      return;
    }
    setState(() => localMessage = null);
  }

  String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return widget.language == KolkhozLanguage.ru
          ? 'ВВЕДИТЕ ЭЛЕКТРОННУЮ ПОЧТУ'
          : 'ENTER EMAIL';
    }
    final at = email.indexOf('@');
    if (at <= 0 ||
        at == email.length - 1 ||
        !email.substring(at + 1).contains('.')) {
      return widget.language == KolkhozLanguage.ru
          ? 'ПРОВЕРЬТЕ АДРЕС ПОЧТЫ'
          : 'ENTER A VALID EMAIL';
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (validationAction == _CloudAuthAction.resetPassword) return null;
    if (value?.isNotEmpty ?? false) return null;
    return widget.language == KolkhozLanguage.ru
        ? 'ВВЕДИТЕ ПАРОЛЬ'
        : 'ENTER PASSWORD';
  }

  String? validateConfirmation(String? value) {
    if (validationAction != _CloudAuthAction.signUp) return null;
    if (value == passwordController.text) return null;
    return widget.language.strings.kolkhozappPasswordsDoNotMatch;
  }

  bool validate(_CloudAuthAction action) {
    setState(() => validationAction = action);
    if (!(formKey.currentState?.validate() ?? false)) return false;
    clearLocalMessage();
    return true;
  }

  void submitSignIn() {
    if (!validate(_CloudAuthAction.signIn)) return;
    TextInput.finishAutofillContext();
    widget.onSignIn?.call(emailController.text.trim(), passwordController.text);
  }

  void submitPasswordReset() {
    if (!validate(_CloudAuthAction.resetPassword)) return;
    widget.onResetPassword?.call(emailController.text.trim());
  }

  void submitSignUp() {
    if (!validate(_CloudAuthAction.signUp)) return;
    TextInput.finishAutofillContext();
    widget.onSignUp?.call(emailController.text.trim(), passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final status = !widget.configured
        ? widget
              .language
              .strings
              .kolkhozappCloudProfilesAreNotConfiguredForThisBuild
        : !widget.ready
        ? widget.language.strings.kolkhozappCloudProfilesAreStarting
        : widget.language.strings.kolkhozappSignInToSyncProfileAndOnlineSeats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(
          widget.language.strings.kolkhozappAccount,
          style: kolkhozFontStyle.copyWith(
            color: widget.tokens.colors.gold,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        VariantRowBackground(
          tokens: widget.tokens,
          active: false,
          child: Text(
            status,
            style: kolkhozFontStyle.copyWith(
              color: widget.tokens.colors.creamDim,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (widget.message != null)
          OnlineStatusBanner(
            tokens: widget.tokens,
            message: widget.message!,
            isError: widget.messageIsError,
          ),
        if (widget.configured && widget.ready && localMessage != null)
          OnlineStatusBanner(
            tokens: widget.tokens,
            message: localMessage!,
            isError: true,
          ),
        if (widget.configured && widget.ready)
          Form(
            key: formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  KolkhozTextField(
                    tokens: widget.tokens,
                    controller: emailController,
                    labelText: widget.language.strings.kolkhozappEmail,
                    enabled: !widget.busy,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLength: maxAccountEmailLength,
                    validator: validateEmail,
                    onChanged: (_) => clearLocalMessage(),
                  ),
                  KolkhozTextField(
                    tokens: widget.tokens,
                    controller: passwordController,
                    labelText: widget.language.strings.kolkhozappPassword,
                    enabled: !widget.busy,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.password],
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLength: 72,
                    validator: validatePassword,
                    onChanged: (_) => clearLocalMessage(),
                  ),
                  KolkhozTextField(
                    tokens: widget.tokens,
                    controller: confirmPasswordController,
                    labelText:
                        widget.language.strings.kolkhozappConfirmPassword,
                    enabled: !widget.busy,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLength: 72,
                    validator: validateConfirmation,
                    onChanged: (_) => clearLocalMessage(),
                    onSubmitted: (_) {
                      if (!widget.busy && widget.onSignUp != null) {
                        submitSignUp();
                      }
                    },
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      SizedBox(
                        width: 142,
                        height: 38,
                        child: ChromeAssetButton.command(
                          label: widget.busy
                              ? widget.language.strings.kolkhozappWorking
                              : widget.language.strings.kolkhozappSignIn,
                          prominent: false,
                          tokens: widget.tokens,
                          onPressed: widget.busy || widget.onSignIn == null
                              ? null
                              : submitSignIn,
                        ),
                      ),
                      SizedBox(
                        width: 142,
                        height: 38,
                        child: ChromeAssetButton.command(
                          label: widget.language.strings.kolkhozappReset,
                          prominent: false,
                          tokens: widget.tokens,
                          onPressed:
                              widget.busy || widget.onResetPassword == null
                              ? null
                              : submitPasswordReset,
                        ),
                      ),
                      SizedBox(
                        width: 142,
                        height: 38,
                        child: ChromeAssetButton.command(
                          label: widget.language.strings.kolkhozappCreate,
                          prominent: true,
                          tokens: widget.tokens,
                          onPressed: widget.busy || widget.onSignUp == null
                              ? null
                              : submitSignUp,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
