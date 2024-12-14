import 'package:encrypt/encrypt.dart';
import 'package:flutter_local_db/src/notifiers/local_database_notifier.dart';

class AESEncryptor {
  static String encrypt(String plainText) {
    if (plainText.trim().isEmpty) return "";
    assert(configNotifier.value.hashEncrypt.length == 16);
    final cipherKey = Key.fromUtf8(configNotifier.value.hashEncrypt);
    final encryptService = Encrypter(AES(cipherKey));
    final initVector = IV.fromUtf8(configNotifier.value.hashEncrypt);

    Encrypted encryptedData = encryptService.encrypt(plainText, iv: initVector);
    return encryptedData.base64;
  }

  static String decrypt(String encryptedData) {
    if (encryptedData.trim().isEmpty) return "";
    assert(configNotifier.value.hashEncrypt.length == 16);
    final cipherKey = Key.fromUtf8(configNotifier.value.hashEncrypt);
    final encryptService = Encrypter(AES(cipherKey));
    final initVector = IV.fromUtf8(configNotifier.value.hashEncrypt);

    return encryptService.decrypt(Encrypted.fromBase64(encryptedData),
        iv: initVector);
  }
}
