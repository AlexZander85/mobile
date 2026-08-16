import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:lichess_mobile/src/constants.dart';

final hmacSha1 = Hmac(sha1, utf8.encode(kLichessWSSecret));

/// Returns the bearer value expected by the configured Lichess authentication mode.
///
/// Official mobile tokens use the concealed `web:mobile` scope and must be HMAC-signed. Public
/// Board API test tokens use ordinary OAuth scopes and must be sent verbatim; signing them would
/// turn a valid public token into an invalid bearer value.
String signBearerToken(String token) {
  if (kPublicBoardApiTest) return token;
  final digest = hmacSha1.convert(utf8.encode(token));
  return '$token:$digest';
}
