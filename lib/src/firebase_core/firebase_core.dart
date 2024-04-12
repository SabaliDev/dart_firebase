import 'dart:convert';
import 'package:lightspeed_server/src/frontier/build_secrets/lib/env/firebase_config/firebase_service_account.dart';
import 'package:firebase_admin/firebase_admin.dart';
import 'package:googleapis/firestore/v1.dart';
import 'package:googleapis_auth/auth_io.dart';

import 'package:logging/logging.dart';

final Logger _logger = Logger("FirebaseCore");

class FirebaseCore {
  Codec<String, String> stringToBase64 = utf8.fuse(base64);

  Future<FirestoreApi?> getFirestoreClient() async {
    try {
      final authClient = await getGCloudAuthClient();
      final firestoreClient = FirestoreApi(authClient!);
      return firestoreClient;
    } on Error catch (e) {
      _logger.warning("${e.stackTrace.toString()} ${e.toString()}");
      return null;
    }
  }

  Future<AutoRefreshingAuthClient?> getGCloudAuthClient() async {
    try {
      final accountCredentials = ServiceAccountCredentials(
          FirebaseServiceAccount.clientEmail,
          ClientId(FirebaseServiceAccount.clientId),
          stringToBase64.decode(FirebaseServiceAccount.privateKeyBase64));

      final authClient = await clientViaServiceAccount(
          accountCredentials, [FirestoreApi.datastoreScope]);

      return authClient;
    } on Error catch (e) {
      _logger.warning("${e.stackTrace.toString()} ${e.toString()}");
      return null;
    }
  }

  Future<Auth?> getFirebaseAuthClient() async {
    try {
      final firebaseAuthClient = FirebaseAdmin.instance.app()?.auth();

      return firebaseAuthClient;
    } on Error catch (e) {
      _logger.warning("${e.stackTrace.toString()} ${e.toString()}");
      return null;
    }
  }
}
