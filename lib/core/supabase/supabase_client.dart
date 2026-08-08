// ════════════════════════════════════════════════
// Project Lyra — Supabase Client
// ════════════════════════════════════════════════

import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase client wrapper.
class LyraSupabase {
  LyraSupabase._();

  static LyraSupabase? _instance;
  static LyraSupabase get instance => _instance ??= LyraSupabase._();

  late SupabaseClient _client;

  /// The underlying Supabase client.
  SupabaseClient get client => _client;

  /// The auth instance.
  GoTrueClient get auth => _client.auth;

  /// The storage instance.
  SupabaseStorageClient get storage => _client.storage;

  /// The functions instance.
  FunctionsClient get functions => _client.functions;

  /// Initialize Supabase.
  Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://jzxtxqjheggyoqwohqjg.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp6eHR4cWpoZWdneW9xd29ocWpnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYxODM4OTcsImV4cCI6MjEwMTc1OTg5N30.fD6pKQ4VRG-AoF-nLdpU9iMK1qWz4N-diqMUOJESVw8',
    );

    _client = Supabase.instance.client;
  }

  /// Get the current user ID.
  String? get currentUserId => auth.currentUser?.id;

  /// Whether the user is authenticated.
  bool get isAuthenticated => auth.currentUser != null;

  /// Sign in with email and password.
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign up with email and password.
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    return await auth.signUp(
      email: email,
      password: password,
      data: displayName != null ? {'display_name': displayName} : null,
    );
  }

  /// Sign in with Google OAuth.
  Future<bool> signInWithGoogle() async {
    return await auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.vshots.live://login-callback',
    );
  }

  /// Sign out.
  Future<void> signOut() async {
    await auth.signOut();
  }

  /// Send password reset email.
  Future<void> resetPassword(String email) async {
    await auth.resetPasswordForEmail(email);
  }

  /// Query a table.
  Future<List<Map<String, dynamic>>> query({
    required String table,
    String select = '*',
    Map<String, dynamic>? filters,
    String? orderBy,
    bool ascending = false,
    int? limit,
  }) async {
    dynamic queryBuilder = _client.from(table).select(select);

    if (filters != null) {
      for (final entry in filters.entries) {
        queryBuilder = queryBuilder.eq(entry.key, entry.value);
      }
    }

    if (orderBy != null) {
      queryBuilder = queryBuilder.order(orderBy, ascending: ascending);
    }

    if (limit != null) {
      queryBuilder = queryBuilder.limit(limit);
    }

    return List<Map<String, dynamic>>.from(await queryBuilder);
  }

  /// Insert a row.
  Future<Map<String, dynamic>> insert({
    required String table,
    required Map<String, dynamic> data,
  }) async {
    return await _client.from(table).insert(data).select().single();
  }

  /// Update a row.
  Future<Map<String, dynamic>> update({
    required String table,
    required Map<String, dynamic> data,
    required String id,
  }) async {
    return await _client
        .from(table)
        .update(data)
        .eq('id', id)
        .select()
        .single();
  }

  /// Delete a row.
  Future<void> delete({
    required String table,
    required String id,
  }) async {
    await _client.from(table).delete().eq('id', id);
  }

  /// Call an RPC function.
  Future<dynamic> rpc({
    required String functionName,
    Map<String, dynamic>? params,
  }) async {
    return await _client.rpc(functionName, params: params);
  }

  /// Dispose the client.
  Future<void> dispose() async {
    await _client.dispose();
  }
}
