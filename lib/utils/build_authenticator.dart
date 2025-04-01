import 'package:amplify_authenticator/amplify_authenticator.dart';
import 'package:flutter/material.dart';
import 'custom_scaffold_widget.dart';

Widget? buildAuthenticator(BuildContext context, AuthenticatorState state) {
  switch (state.currentStep) {
    case AuthenticatorStep.signIn:
      return CustomScaffold(
        state: state,
        body: SignInForm(),
        footer: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Don\'t have an account?'),
            TextButton(
              onPressed: () => state.changeStep(
                AuthenticatorStep.signUp,
              ),
              child: const Text('Sign Up'),
            ),
          ],
        ),
      );
    case AuthenticatorStep.signUp:
      return CustomScaffold(
        state: state,
        body: SignUpForm(),
        footer: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Already have an account?'),
            TextButton(
              onPressed: () => state.changeStep(
                AuthenticatorStep.signIn,
              ),
              child: const Text('Sign In'),
            ),
          ],
        ),
      );
    case AuthenticatorStep.confirmSignUp:
      return CustomScaffold(
        state: state,
        body: ConfirmSignUpForm(),
      );
    case AuthenticatorStep.resetPassword:
      return CustomScaffold(
        state: state,
        body: ResetPasswordForm(),
      );
    case AuthenticatorStep.confirmResetPassword:
      return CustomScaffold(
        state: state,
        body: const ConfirmResetPasswordForm(),
      );
    default:
      return null;
  }
}
