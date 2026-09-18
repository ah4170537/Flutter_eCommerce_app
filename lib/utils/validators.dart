class Validators {
  Validators._();

  static const int minPasswordLength = 8;

  static bool isValidEmail(String email) {
  return RegExp(r'^[\w\.\+\-]+@([\w\-]+\.)+[\w\-]{2,4}$')
      .hasMatch(email.trim());
}

  static bool isValidPassword(String password) {
    return password.length >= minPasswordLength;
  }

  static String? emailError(String value) {
    if (value.trim().isEmpty) return "Email is required";
    if (!isValidEmail(value)) return "Enter a valid email address";
    return null;
  }

  static String? passwordError(String value) {
    if (value.isEmpty) return "Password is required";
    if (!isValidPassword(value)) {
      return "Password must be at least $minPasswordLength characters";
    }
    return null;
  }
}
