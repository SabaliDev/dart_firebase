import 'package:envied/envied.dart';

part 'firebase_config.g.dart';

@Envied(path: 'lib/src/build_secrets/firebase_config/firebase_config.env')
abstract class FirebaseCredentials {
  @EnviedField(varName: 'FIREBASE_API_KEY', obfuscate: true)
  static final String firebaseApiKey = _FirebaseCredentials.firebaseApiKey;
  @EnviedField(varName: 'FIREBASE_AUTH_DOMAIN', obfuscate: true)
  static final String firebaseAuthDomain =
      _FirebaseCredentials.firebaseAuthDomain;
  @EnviedField(varName: 'FIREBASE_PROJECT_ID', obfuscate: true)
  static final String firebaseProjectId =
      _FirebaseCredentials.firebaseProjectId;
  @EnviedField(varName: 'FIREBASE_STORAGE_BUCKET', obfuscate: true)
  static final String firebaseStorageBucket =
      _FirebaseCredentials.firebaseStorageBucket;
  @EnviedField(varName: 'FIREBASE_MESSAGING_SENDER_ID', obfuscate: true)
  static final String firebaseMessagingSenderID =
      _FirebaseCredentials.firebaseMessagingSenderID;
  @EnviedField(varName: 'FIREBASE_APP_ID', obfuscate: true)
  static final String firebaseAppId = _FirebaseCredentials.firebaseAppId;
  @EnviedField(varName: 'FIREBASE_MEASUREMENT_ID', obfuscate: true)
  static final String firebaseMeasurementId =
      _FirebaseCredentials.firebaseMeasurementId;
  @EnviedField(varName: 'GOOGLE_MAPS_API_KEY', obfuscate: true)
  static final String googleMapsAPIKey = _FirebaseCredentials.googleMapsAPIKey;
}
