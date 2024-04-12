import 'package:envied/envied.dart';

part 'firebase_service_account.g.dart';

@Envied(
    path:
        'lib/src/frontier/build_secrets/lib/env/firebase_config/firebase_service_account.env')
abstract class FirebaseServiceAccount {
  @EnviedField(varName: 'FIREBASE_PROJECT_ID', obfuscate: true)
  static final String firebaseProjectId =
      _FirebaseServiceAccount.firebaseProjectId;
  @EnviedField(varName: 'PRIVATE_KEY_ID', obfuscate: true)
  static final String privateKeyId = _FirebaseServiceAccount.privateKeyId;
  @EnviedField(varName: 'PRIVATE_KEY_BASE_64', obfuscate: true)
  static final String privateKeyBase64 =
      _FirebaseServiceAccount.privateKeyBase64;
  @EnviedField(varName: 'CLIENT_EMAIL', obfuscate: true)
  static final String clientEmail = _FirebaseServiceAccount.clientEmail;
  @EnviedField(varName: 'CLIENT_ID', obfuscate: true)
  static final String clientId = _FirebaseServiceAccount.clientId;
  @EnviedField(varName: 'AUTH_URI', obfuscate: true)
  static final String authUri = _FirebaseServiceAccount.authUri;
  @EnviedField(varName: 'TOKEN_URI', obfuscate: true)
  static final String tokenUri = _FirebaseServiceAccount.tokenUri;
  @EnviedField(varName: 'AUTH_PROVIDER_X509_CERT_URL', obfuscate: true)
  static final String authProviderX509CertUrl =
      _FirebaseServiceAccount.authProviderX509CertUrl;
  @EnviedField(varName: 'CLIENT_X509_CERT_URL', obfuscate: true)
  static final String clientX509CertUrl =
      _FirebaseServiceAccount.clientX509CertUrl;
  @EnviedField(varName: 'UNIVERSE_DOMAIN', obfuscate: true)
  static final String universeDomain = _FirebaseServiceAccount.universeDomain;
}
