class UsefulFunctions {
  String ToCamelCase(String input) {
    List<String> words = input.split(RegExp(r'\s+|_+|-+'));

    if (words.isEmpty) {
      return '';
    }

    String camelCaseString = '';

    for (int i = 0; i < words.length; i++) {
      camelCaseString +=
          words[i][0].toUpperCase() + words[i].substring(1).toLowerCase();
    }

    return camelCaseString;
  }
}
