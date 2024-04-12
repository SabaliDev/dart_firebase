import 'package:intl/intl.dart';
import 'package:lightspeed_server/src/frontier/build_secrets/lib/env/firebase_config/firebase_service_account.dart';
import 'package:googleapis/firestore/v1.dart';
import 'package:logging/logging.dart';

final Logger _logger = Logger("FirestoreCRUD");

class FirestoreCRUD {
  FirestoreApi api;
  AuthorizationState authorizationState;
  AuthenticationState authenticationState;
  FirestoreSecurity fSec;

  FirestoreCRUD(this.api, this.authorizationState, this.authenticationState,
      {FirestoreSecurity? fSec})
      : fSec =
            fSec ?? FirestoreSecurity(authorizationState, authenticationState);

// ===============
// WRITE
// ===============

  Future<String?> writeToFirestore(
      {required String collection,
      String? documentId,
      required Map<String, dynamic> data}) async {
    try {
      // Run authorization checks
      final isAuthorized = await _authorizedToWrite(
          collection: collection, data: data, documentId: documentId);
      if (!isAuthorized) {
        throw Exception("Unauthorized to write to $collection");
      }
      Document document = Document(fields: prepareFields(data));

      final doc = await api.projects.databases.documents.createDocument(
          document,
          'projects/${FirebaseServiceAccount.firebaseProjectId}/databases/(default)/documents',
          collection,
          documentId: documentId);
      _logger.finer(doc.name);

      return doc.name?.split("/").last;
    } on ApiRequestError catch (e, stackTrace) {
      _logger.warning(
          "API Error while Writing to Firestore", e.message, stackTrace);
    } on Exception catch (e, stackTrace) {
      _logger.severe("Error Writing to Firestore", e.toString(), stackTrace);
    }
    return null;
  }

  Map<String, Value> prepareFields(Map<dynamic, dynamic> data) {
    Map<String, Value> finalData = {};
    data.forEach((key, value) {
      if (value != null) {
        finalData[key] = _prepareValues(value);
      }
    });
    return finalData;
  }

  Value _prepareValues(Object value) {
    if ((value.toString().contains("-") || value.toString().contains("/")) &&
        DateTime.tryParse(value.toString()) != null) {
      // RFC 3339 format
      DateTime date = DateTime.parse(value.toString()).toUtc();
      final DateFormat formatter = DateFormat('yyyy-MM-ddTHH:mm:ss.SSS\'Z\'');
      String rfc3339Date = formatter.format(date);
      return Value(timestampValue: rfc3339Date);
    } else if (value is String) {
      return Value(stringValue: value);
    } else if (value is int) {
      return Value(integerValue: value.toString());
    } else if (value is double) {
      return Value(doubleValue: value);
    } else if (value is Map) {
      return Value(mapValue: MapValue(fields: prepareFields(value)));
    } else if (value is bool) {
      return Value(booleanValue: value);
    } else if (value is List) {
      List<Value> values = [];
      for (var element in value) {
        values.add(_prepareValues(element));
      }
      return Value(arrayValue: ArrayValue(values: values));
    } else {
      return Value(nullValue: null);
    }
  }

// ==================
// Query Firestore
// ==================

  Future<List<FirestoreDocument>?> queryFirestore(
      {required String collection,
      int? limit,
      required List<FirestoreQueryParameter> queryParams}) async {
    try {
      // DEFINE FILTER OBJECTS
      FieldFilter? fieldFilter;
      CompositeFilter? compositeFilter;
      if (queryParams.isEmpty) {
        // No Filters, Return null
        return null;
      } else if (queryParams.length == 1) {
        // In case of only one filter, use FieldFilter
        fieldFilter = FieldFilter(
            field: FieldReference(fieldPath: queryParams.first.fieldName),
            op: queryParams.first.operator.name,
            value: _prepareValues(queryParams.first.value));
      } else {
        // In case of multiple filters, use CompositeFilter
        List<Filter> fieldFilters = [];
        for (var queryParam in queryParams) {
          fieldFilters.add(Filter(
              fieldFilter: FieldFilter(
                  field: FieldReference(fieldPath: queryParam.fieldName),
                  op: queryParam.operator.name,
                  value: _prepareValues(queryParam.value))));
        }
        compositeFilter = CompositeFilter(op: "AND", filters: fieldFilters);
      }

      final response = await api.projects.databases.documents.runQuery(
          RunQueryRequest(
              structuredQuery: StructuredQuery(
            where: Filter(
              fieldFilter: fieldFilter,
              compositeFilter: compositeFilter,
            ),
            from: [
              CollectionSelector(collectionId: collection, allDescendants: true)
            ],
            limit: limit,
          )),
          'projects/${FirebaseServiceAccount.firebaseProjectId}/databases/(default)/documents');
      if (response.isEmpty || response.first.document == null) {
        return null;
      }
      // Convert Response to a list of maps
      List<FirestoreDocument> responseList = [];
      for (var element in response) {
        final responseMap = responseToMap(element.document!.fields!);
        responseList.add(FirestoreDocument(
            documentId: element.document!.name!.split("/").last,
            data: responseMap));
      }

      // Run authorization checks after fetching
      // to verify the user's ownership of the data
      final isAuthorized = await _authorizedToRead(
          collection: collection,
          queryParameters: queryParams,
          dataList: responseList);
      if (!isAuthorized) {
        throw Exception("Unauthorized to read from $collection");
      }

      return responseList;
    } catch (e, stackTrace) {
      _logger.warning("Error on querying firestore", e.toString(), stackTrace);
    }
    return null;
  }

// =========================
// FETCH WITH DOCUMENT ID
// =========================

  Future<FirestoreDocument?> fetchFromFirestoreWithDocId({
    required String collection,
    required String documentId,
  }) async {
    try {
      // Run authorization checks
      final isAuthorized = await _authorizedToRead(
          collection: collection, documentId: documentId);

      if (!isAuthorized) {
        throw Exception("Unauthorized to read from $collection");
      }

      final response = await api.projects.databases.documents.get(
          "projects/${FirebaseServiceAccount.firebaseProjectId}/databases/(default)/documents/$collection/$documentId");

      return FirestoreDocument(
          documentId: response.name!.split("/").last,
          data: responseToMap(response.fields!));
    } on ApiRequestError catch (e, stackTrace) {
      _logger.warning("API Error Fetching from Firestore with documentID",
          e.message, stackTrace);
    } on Exception catch (e, stackTrace) {
      _logger.severe("Error Fetching from Firestore with documentID",
          e.toString(), stackTrace);
    }
    return null;
  }

  // Convert response to Map<String, dynamic>
  Map<String, dynamic> responseToMap(Map<String, Value> response) {
    Map<String, dynamic> responseMap = {};
    response.forEach((key, value) {
      responseMap[key] = _prepareResponseValues(value);
    });
    return responseMap;
  }

  dynamic _prepareResponseValues(Value value) {
    if (value.timestampValue != null) {
      return value.timestampValue!;
    } else if (value.integerValue != null) {
      return int.tryParse(value.integerValue!);
    } else if (value.stringValue != null) {
      return value.stringValue!;
    } else if (value.doubleValue != null) {
      return value.doubleValue!;
    } else if (value.mapValue != null) {
      if (value.mapValue!.fields == null || value.mapValue!.fields!.isEmpty) {
        return {};
      }
      return responseToMap(value.mapValue!.fields!);
    } else if (value.booleanValue != null) {
      return value.booleanValue!;
    } else if (value.arrayValue != null) {
      List<dynamic> values = [];
      if (value.arrayValue!.values == null ||
          value.arrayValue!.values!.isEmpty) {
        return values;
      }
      for (var element in value.arrayValue!.values!) {
        values.add(_prepareResponseValues(element));
      }
      return values;
    } else {
      return null;
    }
  }

// =========================
// UPDATE WITH DOCUMENT ID
// =========================

// Requires a map of data
// Collection name & documentId
// [Optional] Specify if document must/must-NOT exist for the operation to happen

  Future<String?> updateDocumentWithDocId(
      {required String collection,
      required String documentId,
      required Map<String, dynamic> data,
      bool? documentExists}) async {
    try {
      // Run authorization checks
      final isAuthorized = await _authorizedToRead(
          collection: collection, documentId: documentId);

      if (!isAuthorized) {
        throw Exception("Unauthorized to update $collection");
      }

      Document document = Document(fields: prepareFields(data));

      final doc = await api.projects.databases.documents.patch(document,
          'projects/${FirebaseServiceAccount.firebaseProjectId}/databases/(default)/documents/$collection/$documentId',
          currentDocument_exists: documentExists,
          updateMask_fieldPaths: document.fields!.keys.toList());

      return doc.name;
    } on ApiRequestError catch (e, stackTrace) {
      _logger.warning("API Error Updating a firestore document with documentID",
          e.message, stackTrace);
    } on Exception catch (e, stackTrace) {
      _logger.severe("Error Updating a firestore document with documentID",
          e.toString(), stackTrace);
    }
    return null;
  }

// =========================
// UPDATE WITH PARAMETERS
// =========================

  Future<String?> updateDocument(
      {required String collection,
      required Operator operator,
      required String fieldName,
      required Object value,
      required Map<String, dynamic> updateData,
      bool? documentExists}) async {
    try {
      final response = await api.projects.databases.documents.runQuery(
          RunQueryRequest(
              structuredQuery: StructuredQuery(
            where: Filter(
                fieldFilter: FieldFilter(
                    field: FieldReference(fieldPath: fieldName),
                    value: Value(stringValue: value.toString()),
                    op: operator.name)),
            from: [
              CollectionSelector(collectionId: collection, allDescendants: true)
            ],
          )),
          'projects/${FirebaseServiceAccount.firebaseProjectId}/databases/(default)/documents');

      final documentPath = response.first.document?.name;

      // Run authorization checks
      final isAuthorized = await _authorizedToUpdate(
          collection: collection,
          data: responseToMap(response.first.document!.fields!));
      if (!isAuthorized) {
        throw Exception("Unauthorized to read from $collection");
      }

      if (documentPath != null) {
        Document document = Document(fields: prepareFields(updateData));

        final doc = await api.projects.databases.documents.patch(
            document, documentPath,
            currentDocument_exists: documentExists,
            updateMask_fieldPaths: document.fields!.keys.toList());
        return doc.name;
      } else {
        _logger.info("No matching document found!");
        return "No matching document found!";
      }
    } on ApiRequestError catch (e, stackTrace) {
      _logger.warning(
          "API Error Updating firestore documents", e.message, stackTrace);
    } on Exception catch (e, stackTrace) {
      _logger.severe(
          "Error Updating firestore documents", e.toString(), stackTrace);
    }
    return null;
  }

// ========================
// BATCH UPDATE
// ========================

// Updates All documents that satisfy the conditions supplied
  Future<String?> updateMultipleDocuments(
      {required String collection,
      required Operator operator,
      required String fieldName,
      required Object value,
      required Map<String, dynamic> updateData,
      bool? documentExists}) async {
    try {
      // only accessible by admins
      final isAuthorized = fSec.isPuulseAdmin();
      !isAuthorized
          ? throw Exception("Unauthorized to batch update $collection")
          : null;

      final response = await api.projects.databases.documents.runQuery(
          RunQueryRequest(
              structuredQuery: StructuredQuery(
            where: Filter(
                fieldFilter: FieldFilter(
                    field: FieldReference(fieldPath: fieldName),
                    value: Value(stringValue: value.toString()),
                    op: operator.name)),
            from: [
              CollectionSelector(collectionId: collection, allDescendants: true)
            ],
          )),
          'projects/${FirebaseServiceAccount.firebaseProjectId}/databases/(default)/documents');

      List<Write> writes = [];
      for (var element in response) {
        final documentPath = element.document?.name;
        if (documentPath != null) {
          Document document = Document(fields: prepareFields(updateData));

          writes.add(Write(
              currentDocument: Precondition(exists: documentExists),
              update: Document(
                  fields: prepareFields(updateData), name: documentPath),
              updateMask:
                  DocumentMask(fieldPaths: document.fields!.keys.toList())));
        } else {
          _logger.info("No matching document found!");
          return "No matching document found!";
        }
      }

      final doc = await api.projects.databases.documents.commit(
          CommitRequest(writes: writes, transaction: "transaction"),
          'projects/${FirebaseServiceAccount.firebaseProjectId}/databases/(default)');

      return doc.commitTime;
    } on ApiRequestError catch (e, stackTrace) {
      _logger.warning("API Error Batch Updating firestore documents", e.message,
          stackTrace);
    } on Exception catch (e, stackTrace) {
      _logger.severe(
          "Error Batch Updating firestore documents", e.toString(), stackTrace);
    }
    return null;
  }

// =========================
// DELETE WITH DOCUMENT ID
// =========================

// Deletes a document from a specified collection using its document ID.
// Returns true if the operation is successful.

  Future<bool> deleteDocumentWithId({
    required String collection,
    required String documentId,
  }) async {
    try {
      // Call the Firestore API to delete the document
      await api.projects.databases.documents.delete(
        'projects/${FirebaseServiceAccount.firebaseProjectId}/databases/(default)/documents/$collection/$documentId',
      );

      return true;
    } on ApiRequestError catch (e, stackTrace) {
      _logger.warning(
          "API Error deleting firestore document", e.message, stackTrace);
      return false;
    } on Exception catch (e, stackTrace) {
      _logger.severe(
          "Error deleting firestore document", e.toString(), stackTrace);
      return false;
    }
  }

// ============================
// DELETE FIELD IN DOCUMENT
// ============================

// Deletes a specific field from a document in a specified collection using its document ID.
// Returns true if the operation is successful.

  Future<bool> deleteFieldFromDocument({
    required String collection,
    required String documentId,
    required String field,
  }) async {
    try {
      // Prepare the update to set the field value to null
      var fields = {field: Value(nullValue: "NULL_VALUE")};

      // Call the Firestore API to update the document with the field set to null
      await api.projects.databases.documents.patch(
        Document(fields: fields),
        'projects/${FirebaseServiceAccount.firebaseProjectId}/databases/(default)/documents/$collection/$documentId',
        updateMask_fieldPaths: [field], // Specify the field path to delete
      );

      _logger.finer("Field deleted successfully.");
      return true;
    } on ApiRequestError catch (e, stackTrace) {
      _logger.warning(
          "API Error deleting firestore document", e.toString(), stackTrace);
      return false;
    } on Exception catch (e, stackTrace) {
      _logger.warning(
          "Error deleting firestore document", e.toString(), stackTrace);
      return false;
    }
  }
}
