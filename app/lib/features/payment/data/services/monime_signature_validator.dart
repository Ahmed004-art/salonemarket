import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Dart implementation of the official Monime HMAC-SHA256 signature verification.
/// Matches https://docs.monime.io/docs/developer-resources/guides/webhook/hmac-verification
class MonimeSignatureValidator {
  const MonimeSignatureValidator._();

  static const int defaultMaxAgeSeconds = 300; // 5 minutes
  static const int defaultMaxFutureSeconds = 60; // 60 seconds

  /// Computes Monime HMAC-SHA256 signature:
  /// base64_encode(HMAC-SHA256(secret, timestamp + "_" + rawBody))
  static String computeSignature({
    required int timestamp,
    required String rawBody,
    required String secret,
  }) {
    final signedPayload = '${timestamp}_$rawBody';
    final keyBytes = utf8.encode(secret);
    final dataBytes = utf8.encode(signedPayload);
    final hmacSha256 = Hmac(sha256, keyBytes);
    final digest = hmacSha256.convert(dataBytes);
    return base64.encode(digest.bytes);
  }

  /// Parses `monime-signature` header: "t=1773386779,v1=eYpwGr..."
  static Map<String, String> parseHeader(String? header) {
    if (header == null || header.trim().isEmpty) return {};
    final map = <String, String>{};
    for (final pair in header.split(',')) {
      final parts = pair.split('=');
      if (parts.length >= 2) {
        map[parts[0].trim()] = parts.sublist(1).join('=').trim();
      }
    }
    return map;
  }

  /// Constant-time byte comparison to prevent timing attacks.
  static bool timingSafeEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// Verifies a Monime webhook delivery.
  static WebhookVerificationResult verify({
    required String? signatureHeader,
    required String rawBody,
    required String? secret,
    int? nowUnixSeconds,
    int maxAgeSeconds = defaultMaxAgeSeconds,
    int maxFutureSeconds = defaultMaxFutureSeconds,
  }) {
    if (secret == null || secret.trim().isEmpty) {
      return const WebhookVerificationResult(
        isValid: false,
        statusCode: 500,
        errorMessage: 'Webhook secret is not configured on the server.',
      );
    }

    if (signatureHeader == null || signatureHeader.trim().isEmpty) {
      return const WebhookVerificationResult(
        isValid: false,
        statusCode: 401,
        errorMessage: 'Missing monime-signature header.',
      );
    }

    final parsed = parseHeader(signatureHeader);
    final timestampStr = parsed['t'];
    final receivedSig = parsed['v1'];

    if (timestampStr == null || receivedSig == null) {
      return const WebhookVerificationResult(
        isValid: false,
        statusCode: 401,
        errorMessage: 'Malformed signature header: missing t or v1.',
      );
    }

    final timestamp = int.tryParse(timestampStr);
    if (timestamp == null) {
      return const WebhookVerificationResult(
        isValid: false,
        statusCode: 401,
        errorMessage: 'Invalid timestamp in signature header.',
      );
    }

    final now = nowUnixSeconds ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);

    // 1. Replay attack: check timestamp freshness
    final age = now - timestamp;
    if (age > maxAgeSeconds) {
      return WebhookVerificationResult(
        isValid: false,
        statusCode: 401,
        errorMessage: 'Webhook timestamp expired (age: ${age}s > ${maxAgeSeconds}s).',
        timestamp: timestamp,
      );
    }

    if (timestamp - now > maxFutureSeconds) {
      return WebhookVerificationResult(
        isValid: false,
        statusCode: 401,
        errorMessage: 'Webhook timestamp too far in future (${timestamp - now}s > ${maxFutureSeconds}s).',
        timestamp: timestamp,
      );
    }

    // 2. Decode received signature
    List<int> receivedBytes;
    try {
      receivedBytes = base64.decode(receivedSig);
    } catch (_) {
      return WebhookVerificationResult(
        isValid: false,
        statusCode: 401,
        errorMessage: 'Invalid base64 encoding in signature.',
        timestamp: timestamp,
      );
    }

    if (receivedBytes.length != 32) {
      return WebhookVerificationResult(
        isValid: false,
        statusCode: 401,
        errorMessage: 'Invalid signature length (expected 32-byte HMAC-SHA256).',
        timestamp: timestamp,
      );
    }

    // 3. Compute expected signature
    final expectedSig = computeSignature(
      timestamp: timestamp,
      rawBody: rawBody,
      secret: secret,
    );
    final expectedBytes = base64.decode(expectedSig);

    // 4. Timing-safe comparison
    final isMatch = timingSafeEqual(receivedBytes, expectedBytes);
    if (!isMatch) {
      return WebhookVerificationResult(
        isValid: false,
        statusCode: 401,
        errorMessage: 'Signature mismatch: request is forged or payload tampered.',
        timestamp: timestamp,
      );
    }

    return WebhookVerificationResult(
      isValid: true,
      statusCode: 200,
      timestamp: timestamp,
    );
  }
}

class WebhookVerificationResult {
  const WebhookVerificationResult({
    required this.isValid,
    required this.statusCode,
    this.errorMessage,
    this.timestamp,
  });

  final bool isValid;
  final int statusCode;
  final String? errorMessage;
  final int? timestamp;
}
