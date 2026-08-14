class FormValidators {
  static String? required(String? value, {String field = 'Campo'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field obrigatorio.';
    }
    return null;
  }

  static String? email(String? value) {
    final requiredError = required(value, field: 'E-mail');
    if (requiredError != null) return requiredError;

    final pattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!pattern.hasMatch(value!.trim())) {
      return 'Informe um e-mail valido.';
    }
    return null;
  }

  static String? phoneBr(String? value) {
    final requiredError = required(value, field: 'Telefone');
    if (requiredError != null) return requiredError;

    final digits = value!.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10 || digits.length > 11) {
      return 'Informe um telefone com DDD.';
    }
    return null;
  }

  static String? cpf(String? value) {
    final requiredError = required(value, field: 'CPF');
    if (requiredError != null) return requiredError;

    final digits = value!.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(digits)) {
      return 'Informe um CPF valido.';
    }
    return null;
  }

  static String? cnpj(String? value) {
    final requiredError = required(value, field: 'CNPJ');
    if (requiredError != null) return requiredError;

    final digits = value!.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 14 || RegExp(r'^(\d)\1{13}$').hasMatch(digits)) {
      return 'Informe um CNPJ valido.';
    }
    return null;
  }

  static String? date(String? value) {
    final requiredError = required(value, field: 'Data');
    if (requiredError != null) return requiredError;

    final pattern = RegExp(r'^\d{2}/\d{2}/\d{4}$');
    if (!pattern.hasMatch(value!.trim())) {
      return 'Use o formato DD/MM/AAAA.';
    }
    return null;
  }

  static String? time(String? value) {
    final requiredError = required(value, field: 'Hora');
    if (requiredError != null) return requiredError;

    final pattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
    if (!pattern.hasMatch(value!.trim())) {
      return 'Use o formato HH:MM.';
    }
    return null;
  }

  static String? password(String? value) {
    final requiredError = required(value, field: 'Senha');
    if (requiredError != null) return requiredError;

    final text = value!;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(text);
    final hasLower = RegExp(r'[a-z]').hasMatch(text);
    final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(text);
    if (text.length < 8 || !hasUpper || !hasLower || !hasSpecial) {
      return 'Minimo 8 caracteres, maiuscula, minuscula e especial.';
    }
    return null;
  }
}
