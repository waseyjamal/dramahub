import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();

  for (final file in files) {
    String content = file.readAsStringSync();
    if (!content.contains('debugPrint(')) continue;

    bool modified = false;

    if (!content.contains("import 'package:flutter/foundation.dart';")) {
      content = "import 'package:flutter/foundation.dart';\n$content";
      modified = true;
    }

    int index = 0;
    while ((index = content.indexOf('debugPrint(', index)) != -1) {
      String before = content.substring(0, index);
      if (before.trimRight().endsWith('if (kDebugMode) {') || before.trimRight().endsWith('if(kDebugMode){')) {
        index += 10;
        continue;
      }
      
      int openParen = 0;
      int endIndex = -1;
      bool inString = false;
      String stringChar = '';

      for (int i = index + 11; i < content.length; i++) {
        String char = content[i];
        
        if (!inString && (char == "'" || char == '"')) {
          inString = true;
          stringChar = char;
        } else if (inString && char == stringChar && content[i-1] != '\\') {
          inString = false;
        } else if (!inString) {
          if (char == '(') openParen++;
          if (char == ')') {
            if (openParen == 0) {
              endIndex = i;
              break;
            } else {
              openParen--;
            }
          }
        }
      }

      if (endIndex != -1) {
        String statement = content.substring(index, endIndex + 1);
        
        int lastArrow = before.lastIndexOf('=>');
        bool isArrow = false;
        if (lastArrow != -1 && before.substring(lastArrow + 2).trim().isEmpty) {
           isArrow = true;
        }

        if (isArrow) {
           int nextCharIndex = endIndex + 1;
           while (nextCharIndex < content.length && content[nextCharIndex].trim().isEmpty) {
             nextCharIndex++;
           }
           String nextChar = content[nextCharIndex];
           
           if (nextChar == ',' || nextChar == ';') {
               content = "${content.substring(0, lastArrow)}{ if (kDebugMode) { $statement; } }${content.substring(endIndex + 1)}";
               index = lastArrow + 15;
               modified = true;
               continue;
           }
        }

        int nextCharIndex = endIndex + 1;
        while (nextCharIndex < content.length && content[nextCharIndex].trim().isEmpty) {
          nextCharIndex++;
        }
        if (content[nextCharIndex] == ';') {
          // Replace debugPrint(...); with if (kDebugMode) { debugPrint(...); }
          content = "${content.substring(0, index)}if (kDebugMode) { $statement; }${content.substring(nextCharIndex + 1)}";
          index += 15;
          modified = true;
          continue;
        }
      }
      index += 10;
    }

    if (modified) {
      file.writeAsStringSync(content);
      print('Updated ${file.path}');
    }
  }
}
