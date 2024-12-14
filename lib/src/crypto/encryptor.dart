import 'package:encrypt/encrypt.dart';
import 'package:flutter_local_db/src/notifiers/local_database_notifier.dart';

/// A utility class that handles AES encryption and decryption for secure data storage
class AESEncryptor {
  /// Encrypts a plain text string using AES encryption with a 16-byte key.
  /// Returns a Base64 encoded string of the encrypted data.
  /// Returns empty string if input is empty or whitespace.
  ///
  /// @param plainText The string to be encrypted
  /// @return The encrypted string in Base64 format
  static String encrypt(String plainText) {
    if (plainText.trim().isEmpty) return "";
    // Verify encryption key length is exactly 16 characters
    assert(configNotifier.value.hashEncrypt.length == 16);

    // Create encryption key and service from configuration
    final cipherKey = Key.fromUtf8(configNotifier.value.hashEncrypt);
    final encryptService = Encrypter(AES(cipherKey));
    final initVector = IV.fromUtf8(configNotifier.value.hashEncrypt);

    // Perform encryption and return Base64 result
    Encrypted encryptedData = encryptService.encrypt(plainText, iv: initVector);
    return encryptedData.base64;
  }

  /// Decrypts an encrypted Base64 string back to plain text.
  /// Returns empty string if input is empty or whitespace.
  ///
  /// @param encryptedData The Base64 encoded encrypted string
  /// @return The decrypted plain text
  static String decrypt(String encryptedData) {
    if (encryptedData.trim().isEmpty) return "";
    // Verify encryption key length is exactly 16 characters
    assert(configNotifier.value.hashEncrypt.length == 16);

    // Create encryption key and service from configuration
    final cipherKey = Key.fromUtf8(configNotifier.value.hashEncrypt);
    final encryptService = Encrypter(AES(cipherKey));
    final initVector = IV.fromUtf8(configNotifier.value.hashEncrypt);

    // Decrypt the Base64 encoded data
    return encryptService.decrypt(Encrypted.fromBase64(encryptedData),
        iv: initVector);
  }
}
