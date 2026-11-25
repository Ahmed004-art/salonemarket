/**
 * Monime Webhook Signature Verification Utility
 * Follows Monime's official HMAC-SHA256 verification specification:
 * https://docs.monime.io/docs/developer-resources/guides/webhook/hmac-verification
 *
 * Algorithm:
 * 1. signed_payload = timestamp + "_" + raw_request_body
 * 2. signature = base64_encode(HMAC-SHA256(secret, signed_payload))
 * 3. header = "t=" + timestamp + ",v1=" + signature
 */

export interface ParsedMonimeSignature {
  timestamp?: number;
  signature?: string;
  scheme?: string;
}

export interface VerificationResult {
  isValid: boolean;
  statusCode: number;
  reason?: string;
  timestamp?: number;
}

/**
 * Parses the `monime-signature` header: "t=1773386779,v1=eYpwGrK..."
 */
export function parseMonimeSignatureHeader(header: string | null): ParsedMonimeSignature {
  if (!header || typeof header !== 'string') {
    return {};
  }

  const parts: Record<string, string> = {};
  for (const pair of header.split(',')) {
    const [key, ...rest] = pair.split('=');
    if (key && rest.length > 0) {
      parts[key.trim()] = rest.join('=').trim();
    }
  }

  const timestampStr = parts['t'];
  const signature = parts['v1'];
  const timestamp = timestampStr ? parseInt(timestampStr, 10) : undefined;

  return {
    timestamp: isNaN(timestamp as number) ? undefined : timestamp,
    signature,
    scheme: 'v1',
  };
}

/**
 * Constant-time comparison to prevent timing attacks.
 */
export function timingSafeEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) {
    return false;
  }
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff === 0;
}

/**
 * Converts a binary string to Uint8Array safely.
 */
export function base64ToUint8Array(base64: string): Uint8Array | null {
  try {
    const binaryStr = atob(base64);
    const bytes = new Uint8Array(binaryStr.length);
    for (let i = 0; i < binaryStr.length; i++) {
      bytes[i] = binaryStr.charCodeAt(i);
    }
    return bytes;
  } catch {
    return null;
  }
}

/**
 * Converts Uint8Array to Base64 string.
 */
export function uint8ArrayToBase64(bytes: Uint8Array): string {
  let binaryStr = '';
  for (let i = 0; i < bytes.length; i++) {
    binaryStr += String.fromCharCode(bytes[i]);
  }
  return btoa(binaryStr);
}

/**
 * Computes the expected HMAC-SHA256 signature for a Monime payload.
 */
export async function computeMonimeSignature(
  timestamp: number,
  rawBody: string,
  secret: string
): Promise<string> {
  const encoder = new TextEncoder();
  const keyData = encoder.encode(secret);
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    keyData,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const signedPayload = `${timestamp}_${rawBody}`;
  const dataToSign = encoder.encode(signedPayload);
  const signatureBuffer = await crypto.subtle.sign('HMAC', cryptoKey, dataToSign);

  return uint8ArrayToBase64(new Uint8Array(signatureBuffer));
}

/**
 * Verifies that the webhook request is authentically from Monime, unmodified,
 * and within the replay tolerance window.
 *
 * Rules:
 * - Reject if header is missing or malformed.
 * - Reject if timestamp is older than maxAgeSeconds (default: 300s / 5min).
 * - Reject if timestamp is further into the future than maxFutureSeconds (default: 60s).
 * - Reconstruct: signed_payload = timestamp + "_" + rawBody
 * - Compute HMAC-SHA256 in constant-time.
 */
export async function verifyMonimeWebhookSignature(options: {
  signatureHeader: string | null;
  rawBody: string;
  secret: string | null | undefined;
  nowUnixSeconds?: number;
  maxAgeSeconds?: number;
  maxFutureSeconds?: number;
}): Promise<VerificationResult> {
  const {
    signatureHeader,
    rawBody,
    secret,
    nowUnixSeconds = Math.floor(Date.now() / 1000),
    maxAgeSeconds = 300,
    maxFutureSeconds = 60,
  } = options;

  if (!secret || secret.trim().length === 0) {
    return {
      isValid: false,
      statusCode: 500,
      reason: 'MONIME_WEBHOOK_SECRET is not configured on the server',
    };
  }

  if (!signatureHeader || signatureHeader.trim().length === 0) {
    return {
      isValid: false,
      statusCode: 401,
      reason: 'Missing monime-signature header',
    };
  }

  const { timestamp, signature } = parseMonimeSignatureHeader(signatureHeader);

  if (!timestamp || !signature) {
    return {
      isValid: false,
      statusCode: 401,
      reason: 'Malformed monime-signature header (missing t or v1)',
    };
  }

  // 1. Replay Protection: Check timestamp freshness
  const ageSeconds = nowUnixSeconds - timestamp;
  if (ageSeconds > maxAgeSeconds) {
    return {
      isValid: false,
      statusCode: 401,
      reason: `Webhook timestamp expired (age: ${ageSeconds}s > limit: ${maxAgeSeconds}s)`,
      timestamp,
    };
  }

  if (timestamp - nowUnixSeconds > maxFutureSeconds) {
    return {
      isValid: false,
      statusCode: 401,
      reason: `Webhook timestamp is too far in the future (${timestamp - nowUnixSeconds}s > limit: ${maxFutureSeconds}s)`,
      timestamp,
    };
  }

  // 2. Decode received signature
  const receivedBytes = base64ToUint8Array(signature);
  if (!receivedBytes || receivedBytes.length !== 32) {
    return {
      isValid: false,
      statusCode: 401,
      reason: 'Invalid signature encoding or length (expected 32-byte HMAC-SHA256 base64)',
      timestamp,
    };
  }

  // 3. Compute expected signature
  const expectedBase64 = await computeMonimeSignature(timestamp, rawBody, secret);
  const expectedBytes = base64ToUint8Array(expectedBase64);

  if (!expectedBytes) {
    return {
      isValid: false,
      statusCode: 500,
      reason: 'Failed to compute HMAC digest',
      timestamp,
    };
  }

  // 4. Timing-safe comparison
  const isMatch = timingSafeEqual(receivedBytes, expectedBytes);
  if (!isMatch) {
    return {
      isValid: false,
      statusCode: 401,
      reason: 'Cryptographic signature mismatch (payload may have been tampered with or incorrect secret)',
      timestamp,
    };
  }

  return {
    isValid: true,
    statusCode: 200,
    timestamp,
  };
}
