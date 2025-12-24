# Certificate Pinning Setup Guide

## Overview

Certificate pinning has been implemented to protect against man-in-the-middle (MITM) attacks. However, you must configure the actual certificate fingerprints before this protection becomes active.

## Current Status

⚠️ **ACTION REQUIRED**: Certificate pinning is installed but not yet configured with actual certificate fingerprints.

The following domains need certificate fingerprints:
- `kxqxnqbgebhqbvfbmgzv.supabase.co`
- `bck48elw.api.sanity.io`
- `i.ytimg.com`
- `ibblb-website.vercel.app`

## How to Get Certificate Fingerprints

### Option 1: Using OpenSSL (Recommended)

For each domain, run this command:

```bash
# For Supabase
echo | openssl s_client -connect kxqxnqbgebhqbvfbmgzv.supabase.co:443 2>/dev/null | \
  openssl x509 -fingerprint -sha256 -noout

# For Sanity
echo | openssl s_client -connect bck48elw.api.sanity.io:443 2>/dev/null | \
  openssl x509 -fingerprint -sha256 -noout

# For YouTube
echo | openssl s_client -connect i.ytimg.com:443 2>/dev/null | \
  openssl x509 -fingerprint -sha256 -noout

# For Vercel
echo | openssl s_client -connect ibblb-website.vercel.app:443 2>/dev/null | \
  openssl x509 -fingerprint -sha256 -noout
```

The output will look like:
```
SHA256 Fingerprint=AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99
```

Copy the fingerprint (the part after the `=`).

### Option 2: Using Browser

1. Open the domain in Safari or Chrome
2. Click the lock icon in the address bar
3. Click "Certificate"
4. Look for "SHA-256 Fingerprint"
5. Copy the fingerprint value

## Configuring Fingerprints

1. Open `IBBLB/Networking/CertificatePinningDelegate.swift`

2. Replace the TODO comments with actual fingerprints:

```swift
private let trustedCertificates: [String: Set<String>] = [
    "kxqxnqbgebhqbvfbmgzv.supabase.co": [
        "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99",
        // Add backup certificate if available
    ],
    "bck48elw.api.sanity.io": [
        "11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF"
    ],
    // ... etc
]
```

## Important Notes

### Multiple Certificates per Domain

It's recommended to pin **2-3 certificates** per domain:
1. Current certificate
2. Backup certificate (from the same CA)
3. Root CA certificate (optional)

This prevents your app from breaking when the server rotates certificates.

### Testing

After configuration:

1. **Test with valid certificates**: App should work normally
   ```swift
   // Run the app and verify all API calls work
   ```

2. **Test with invalid certificates**: Use a proxy like Charles or Burp Suite
   ```
   // Enable SSL Proxying
   // App should FAIL to connect with certificate pinning error
   ```

### Certificate Rotation

When a pinned domain rotates its certificate:

1. You'll see connection failures in DEBUG logs
2. Get the new certificate fingerprint using the commands above
3. Add the new fingerprint to the set in `CertificatePinningDelegate.swift`
4. Remove the old fingerprint after verifying the new one works
5. Release an app update

### Troubleshooting

#### "No pins configured for <domain>"

This is a warning that certificate pinning is not yet active for that domain. The app will still work but without pinning protection.

**Solution**: Add fingerprints for that domain.

#### "Certificate mismatch for <domain>"

The server's certificate doesn't match any pinned fingerprints.

**Possible causes:**
1. Certificate was rotated and you need to update pins
2. MITM attack is being attempted (good - pinning is working!)
3. You're testing with a proxy (expected behavior)

**Solution**:
- If this is production and unexpected, investigate for security incident
- If certificate was rotated, update the fingerprints
- If testing with proxy, this is expected behavior

#### App can't connect to any pinned domains

**Possible causes:**
1. Fingerprints were copied incorrectly
2. Wrong certificate was fingerprinted
3. CDN/load balancer is serving different certificate

**Solution**:
1. Double-check fingerprints match exactly (including colons)
2. Use the openssl command to verify
3. Test from the same network/region as your users

## Security Best Practices

1. **Pin leaf certificate + intermediate**: Provides flexibility during rotation
2. **Don't pin root CA only**: Too broad, defeats the purpose
3. **Monitor expiration dates**: Set reminders to update pins before certificates expire
4. **Test thoroughly**: Certificate issues can break your app completely
5. **Have a rollback plan**: Keep ability to push updates without pinning if needed

## Disabling Pinning (Emergency Only)

If certificate pinning is causing production issues:

1. **Quick fix** (not recommended): Return empty set for problematic domain
   ```swift
   "kxqxnqbgebhqbvfbmgzv.supabase.co": []  // Disables pinning
   ```

2. **Better fix**: Update with correct fingerprints and push update

3. **Nuclear option**: Comment out the pinning delegate in `APIClient.swift`
   ```swift
   // self.session = URLSession(configuration: configuration, delegate: Self.pinningDelegate, delegateQueue: nil)
   self.session = URLSession.shared
   ```

## Example Complete Configuration

```swift
private let trustedCertificates: [String: Set<String>] = [
    "kxqxnqbgebhqbvfbmgzv.supabase.co": [
        "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99",
        "11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF"
    ],
    "bck48elw.api.sanity.io": [
        "22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00"
    ],
    "i.ytimg.com": [
        "33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11"
    ],
    "ibblb-website.vercel.app": [
        "44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22"
    ]
]
```

## Next Steps

1. ✅ Run the openssl commands for each domain
2. ✅ Update `CertificatePinningDelegate.swift` with actual fingerprints
3. ✅ Test the app to ensure all API calls work
4. ✅ Test with proxy to verify pinning blocks MITM
5. ✅ Document certificate expiration dates
6. ✅ Set calendar reminders for rotation

## Additional Resources

- [OWASP Certificate Pinning](https://owasp.org/www-community/controls/Certificate_and_Public_Key_Pinning)
- [Apple Security Documentation](https://developer.apple.com/documentation/security)
- [Let's Encrypt Certificate Transparency](https://crt.sh/)
