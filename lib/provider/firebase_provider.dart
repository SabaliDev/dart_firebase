import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'firebase_provider.g.dart';

final Logger _logger = Logger("FirebaseProvider");

@riverpod
Future<FirestoreCRUD?> firestore(
    FirestoreRef ref,
    AuthorizationState authorizationState,
    AuthenticationState authenticationState) async {
  try {
    final api = await FirebaseCore().getFirestoreClient();
    return FirestoreCRUD(api!, authorizationState, authenticationState);
  } on Error catch (e) {
    _logger.severe(e.toString());
    return null;
  }
}
