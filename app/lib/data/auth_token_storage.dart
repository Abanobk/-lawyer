import 'package:shared_preferences/shared_preferences.dart';

class AuthTokenStorage {
  static const _kAccess = 'auth_access_token';
  static const _kRefresh = 'auth_refresh_token';
  static const _kOfficeCode = 'auth_office_code';
  static const _kLastEmail = 'auth_last_email';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAccess, accessToken);
    await p.setString(_kRefresh, refreshToken);
  }

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String officeCode,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAccess, accessToken);
    await p.setString(_kRefresh, refreshToken);
    await p.setString(_kOfficeCode, officeCode);
  }

  Future<void> saveOfficeCode(String officeCode) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kOfficeCode, officeCode);
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kAccess);
    await p.remove(_kRefresh);
    await p.remove(_kOfficeCode);
    // Keep last email for convenience.
  }

  Future<String?> getAccessToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kAccess);
  }

  Future<String?> getRefreshToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kRefresh);
  }

  Future<String?> getOfficeCode() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kOfficeCode);
  }

  Future<void> saveLastEmail(String email) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLastEmail, email.trim());
  }

  Future<String?> getLastEmail() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_kLastEmail);
    if (v == null) return null;
    final s = v.trim();
    return s.isEmpty ? null : s;
  }
}
