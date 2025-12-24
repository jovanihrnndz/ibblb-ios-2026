# Secrets Configuration Setup Guide

## Overview

This project uses `Secrets.xcconfig` to manage sensitive credentials (API keys, tokens, etc.) securely. This file is excluded from version control via `.gitignore` to prevent accidental exposure of secrets.

## Quick Start

### 1. Create Your Secrets File

```bash
cp Secrets.xcconfig.example Secrets.xcconfig
```

### 2. Configure Xcode to Use Secrets.xcconfig

#### Option A: Via Xcode UI (Recommended)

1. Open `IBBLB.xcodeproj` in Xcode
2. Select the project (IBBLB) in the Project Navigator
3. Select the IBBLB target
4. Go to the "Info" tab
5. Under "Custom iOS Target Properties", add the following keys:
   - Key: `SUPABASE_URL`
   - Type: String
   - Value: `$(SUPABASE_URL)`
   - Key: `SUPABASE_ANON_KEY`
   - Type: String
   - Value: `$(SUPABASE_ANON_KEY)`
6. Go back to the project (not target) settings
7. Select the "Info" tab
8. Under "Configurations", expand both Debug and Release
9. For each configuration, select "Secrets" as the configuration file

#### Option B: Via Info.plist (If Present)

If your project has an Info.plist file:

1. Open `IBBLB/Info.plist` in Xcode
2. Add the following entries:

```xml
<key>SUPABASE_URL</key>
<string>$(SUPABASE_URL)</string>
<key>SUPABASE_ANON_KEY</key>
<string>$(SUPABASE_ANON_KEY)</string>
```

3. Then configure Secrets.xcconfig as shown in Option A, step 9

### 3. Update Secrets.xcconfig with Real Values

Edit `Secrets.xcconfig` and replace the placeholder values:

```xcconfig
SUPABASE_URL = https:/$()/your-actual-project-id.supabase.co
SUPABASE_ANON_KEY = your-actual-anon-key
```

**IMPORTANT:** The `$(/)` in the URL is an xcconfig workaround. Don't remove it!

### 4. Verify Configuration

Build and run the project. If configuration is correct, the app will start normally. If not, you'll see a fatal error with instructions.

## Security Notes

### ⚠️ CRITICAL: Rotate Exposed Key

The Supabase anon key was previously hardcoded in `APIConfig.swift` and committed to git history. This key is **COMPROMISED** and must be rotated immediately:

1. Go to [Supabase Dashboard](https://app.supabase.com/project/kxqxnqbgebhqbvfbmgzv/settings/api)
2. Click "Rotate" next to the anonymous key
3. Copy the new key
4. Update `Secrets.xcconfig` with the new key
5. Revoke the old key (if the dashboard allows)

### Best Practices

1. **Never commit Secrets.xcconfig** - It's in `.gitignore`, keep it that way
2. **Use different keys per environment** - Create separate Supabase projects for dev/staging/production
3. **Rotate keys regularly** - Quarterly rotation recommended
4. **Share secrets securely** - Use password managers (1Password, LastPass) to share with team members
5. **Audit access** - Regularly review who has access to secrets

## Troubleshooting

### Error: "SUPABASE_URL not configured in Info.plist"

**Cause:** The xcconfig file isn't linked properly or Info.plist doesn't have the variable references.

**Solution:**
1. Verify `Secrets.xcconfig` exists and has values
2. Check that the configuration file is linked in project settings
3. Ensure Info.plist or target settings reference `$(SUPABASE_URL)`
4. Clean build folder (Cmd+Shift+K) and rebuild

### Error: "No such file or directory: Secrets.xcconfig"

**Cause:** You haven't created the secrets file yet.

**Solution:**
```bash
cp Secrets.xcconfig.example Secrets.xcconfig
# Then edit Secrets.xcconfig with your actual values
```

### Build succeeds but app crashes at runtime

**Cause:** Values in `Secrets.xcconfig` are still placeholders.

**Solution:** Edit `Secrets.xcconfig` and replace all `your-*` placeholders with actual values.

## Team Collaboration

### For Team Members

When you clone this repository:

1. Copy `Secrets.xcconfig.example` to `Secrets.xcconfig`
2. Ask a team member for the actual credentials (via secure channel)
3. Paste credentials into `Secrets.xcconfig`
4. Configure Xcode as described above

### For CI/CD

In your CI/CD pipeline (GitHub Actions, GitLab CI, etc.):

```yaml
# Example GitHub Actions
- name: Create Secrets Config
  run: |
    cat > Secrets.xcconfig << EOF
    SUPABASE_URL = https://\$(/)${{ secrets.SUPABASE_PROJECT_ID }}.supabase.co
    SUPABASE_ANON_KEY = ${{ secrets.SUPABASE_ANON_KEY }}
    EOF
```

Then configure the secrets in your CI/CD platform's secret management system.

## Alternative: Environment Variables

If you prefer environment variables over xcconfig:

1. Set environment variables:
   ```bash
   export SUPABASE_URL="https://your-project.supabase.co"
   export SUPABASE_ANON_KEY="your-key"
   ```

2. In Xcode, under Build Settings, add User-Defined settings that reference environment variables

3. Update Info.plist to reference these build settings

## Migration from Hardcoded Credentials

This project previously had credentials hardcoded in `APIConfig.swift`. They have been removed and replaced with this secure configuration system. The old credentials are **COMPROMISED** and must be rotated.

### What Changed

**Before:**
```swift
static let supabaseAnonKey = "eyJhbGciOiJI..." // Hardcoded
```

**After:**
```swift
static var supabaseAnonKey: String {
    guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String else {
        fatalError("SUPABASE_ANON_KEY not configured")
    }
    return key
}
```

## Support

If you encounter issues:

1. Check this document's troubleshooting section
2. Verify your xcconfig syntax (no spaces around `=`, use `$(/)`for URL protocols)
3. Clean and rebuild the project
4. Contact the security team for credential access issues

## References

- [Xcode Build Configuration Files](https://nshipster.com/xcconfig/)
- [iOS Security Best Practices](https://developer.apple.com/documentation/security)
- [Supabase Security](https://supabase.com/docs/guides/auth/row-level-security)
