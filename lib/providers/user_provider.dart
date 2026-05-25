import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_provider.dart';
import '../core/app_config.dart';
import '../services/notification_services.dart';

final userProvider = StateNotifierProvider<UserNotifier, AsyncValue<Map<String, dynamic>?>>((ref) {
  final user = ref.watch(authProvider).value;
  return UserNotifier(user, ref);
});

class UserNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  UserNotifier(this.firebaseUser, this.ref) : super(const AsyncValue.loading()) {
    if (firebaseUser != null) {
      fetchUserProfile();
    } else {
      state = const AsyncValue.data(null);
    }
  }

  final User? firebaseUser;
  final Ref ref;
  final String baseUrl = AppConfig.userBaseUrl;

  Future<void> fetchUserProfile() async {
    state = const AsyncValue.loading();
    try {
      final token = await firebaseUser!.getIdToken();
      final response = await http.get(
        Uri.parse('$baseUrl/me'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        // Use the name entered during login if available
        final authNotifier = ref.read(authProvider.notifier);
        if (authNotifier.displayName != null && authNotifier.displayName!.isNotEmpty) {
          data['name'] = authNotifier.displayName;
          debugPrint('DEBUG: Overriding profile name with: ${data['name']}');
        }

        // Safely trigger FCM Token Sync
        NotificationServices.ensureTokenSynced().catchError((e) {
          debugPrint('Error syncing FCM token in fetchUserProfile: $e');
        });

        state = AsyncValue.data(data);
      } else {
        state = AsyncValue.error('Server error (${response.statusCode}): ${response.body}', StackTrace.current);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> shareAccess(String emailToShare, List<String> deviceIds) async {
    try {
      if (firebaseUser == null) return false;
      final token = await firebaseUser!.getIdToken();
      final response = await http.post(
        Uri.parse('$baseUrl/share'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'sharedEmail': emailToShare,
          'deviceIds': deviceIds,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateSharedDevices(String sharedEmail, List<String> deviceIds) async {
    try {
      if (firebaseUser == null) return false;
      final token = await firebaseUser!.getIdToken();
      final response = await http.put(
        Uri.parse('$baseUrl/share/devices'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'sharedEmail': sharedEmail,
          'deviceIds': deviceIds,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> verifyEmailToShare(String emailToShare) async {
    try {
      if (firebaseUser == null) return {'status': 'error', 'message': 'User not authenticated'};
      final token = await firebaseUser!.getIdToken();
      final response = await http.post(
        Uri.parse('$baseUrl/verify-email'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'emailToShare': emailToShare}),
      );
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'error', 'message': 'Network error. Please try again.'};
    }
  }

  Future<bool> acceptInvitation(String ownerEmail) async {
    try {
      if (firebaseUser == null) return false;
      final token = await firebaseUser!.getIdToken();
      final response = await http.post(
        Uri.parse('$baseUrl/invitations/accept'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'ownerEmail': ownerEmail}),
      );
      if (response.statusCode == 200) {
        await fetchUserProfile();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> declineInvitation(String ownerEmail) async {
    try {
      if (firebaseUser == null) return false;
      final token = await firebaseUser!.getIdToken();
      final response = await http.post(
        Uri.parse('$baseUrl/invitations/decline'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'ownerEmail': ownerEmail}),
      );
      if (response.statusCode == 200) {
        await fetchUserProfile();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> revokeAccess(String sharedEmail) async {
    try {
      if (firebaseUser == null) return false;
      final token = await firebaseUser!.getIdToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/revoke-access/${Uri.encodeComponent(sharedEmail)}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> getSharedDetails(String email) async {
    try {
      if (firebaseUser == null) return [];
      final token = await firebaseUser!.getIdToken();
      final response = await http.get(
        Uri.parse('$baseUrl/${Uri.encodeComponent(email)}/shared-details'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Error in getSharedDetails: $e');
    }
    return [];
  }

  Future<void> refreshProfileQuietly() async {
    try {
      if (firebaseUser == null) return;
      final token = await firebaseUser!.getIdToken();
      final response = await http.get(
        Uri.parse('$baseUrl/me'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        final authNotifier = ref.read(authProvider.notifier);
        if (authNotifier.displayName != null && authNotifier.displayName!.isNotEmpty) {
          data['name'] = authNotifier.displayName;
        }

        // Safely trigger FCM Token Sync
        NotificationServices.ensureTokenSynced().catchError((e) {
          debugPrint('Error syncing FCM token in refreshProfileQuietly: $e');
        });

        state = AsyncValue.data(data);
      }
    } catch (e) {
      debugPrint('Error in refreshProfileQuietly: $e');
    }
  }

  Future<bool> updateAlertSound(bool value) async {
    try {
      if (firebaseUser == null) return false;
      final token = await firebaseUser!.getIdToken();
      final response = await http.put(
        Uri.parse('$baseUrl/settings/alert-sound'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'alertSoundEnabled': value}),
      );

      if (response.statusCode == 200) {
        if (state.value != null) {
          final updatedData = Map<String, dynamic>.from(state.value!);
          updatedData['settings'] ??= {};
          updatedData['settings']['alertSoundEnabled'] = value;
          state = AsyncValue.data(updatedData);
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateProfileName(String newName) async {
    try {
      if (firebaseUser == null) return false;
      final token = await firebaseUser!.getIdToken();
      final response = await http.put(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'name': newName}),
      );

      if (response.statusCode == 200) {
        if (state.value != null) {
          final updatedData = Map<String, dynamic>.from(state.value!);
          updatedData['name'] = newName;
          state = AsyncValue.data(updatedData);
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateDevicesOrder(List<String> deviceIds) async {
    try {
      if (firebaseUser == null) return false;
      final token = await firebaseUser!.getIdToken();
      final response = await http.put(
        Uri.parse('$baseUrl/profile/devices/order'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'deviceIds': deviceIds}),
      );

      if (response.statusCode == 200) {
        if (state.value != null) {
          final updatedData = Map<String, dynamic>.from(state.value!);
          updatedData['assignedDevices'] = deviceIds;
          state = AsyncValue.data(updatedData);
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating devices order: $e');
      return false;
    }
  }
}

