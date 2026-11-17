# MikroTik RouterOS API Deploy Hook v1.2.1

**Release Date**: November 17, 2026  
**Copyright**: (c) CyB0rgg <dev@bluco.re>

## 🐛 Bug-fix release — the wrong certificate was being bound on renewal

If you run v1.2.0 or earlier, **every renewal after the first one bound the previous certificate** to your services and renamed it to the new `domain-YYYYMMDD` name, while the freshly imported certificate was left as `temp-<domain>-<timestamp>.cer_0`. The hook reported success, so RouterOS quietly kept serving an expired certificate. Upgrade and run one deployment (`acme.sh --deploy -d <domain> --deploy-hook mikrotik`) to repair the bindings; the old certificate is parked as `<name>-superseded-<epoch>` and can be removed.

### Fixed
- **Step 2 selected the certificate by common-name and took the first match** — now the imported certificate is located by its **serial number** (`find_certificate_by_serial`).
- **Import verification could never fail** — a serial mismatch was logged and ignored; a missing serial now aborts the deployment before any service is touched.
- **Final rename blocked by the previous certificate** — a certificate already holding the target name is renamed to `<name>-superseded-<epoch>` first (`free_certificate_name`).
- **Spurious "service using certificate 'none'" warning** — the service check read the first `certificate` field of the whole `/ip/service` response (typically the dynamic `reverse-proxy` entry) instead of the requested service's object (`service_certificate_from_response`).
- **Step 6 summary** now reports the certificate carrying the final name only.

### Added
- `tests/test_certificate_selection.sh` — 13 unit tests for the selection, rename-collision and service-check helpers; runs without a router.

### Verified
- RouterOS 7.23.8 (long-term), ZeroSSL ECC certificate via acme.sh 3.1.7, two consecutive live deployments (repair run + idempotent re-run).

---

# MikroTik RouterOS API Deploy Hook v1.2.0

**Release Date**: August 18, 2025  
**Copyright**: (c) CyB0rgg <dev@bluco.re>

## 🎯 What's New in v1.2.0

This release introduces **automatic certificate chain support** to eliminate SSL/TLS validation issues and provide complete trust chains on your MikroTik RouterOS devices.

### 🔗 **Certificate Chain Support**
- **Automatic Intermediate CA Upload** - Extracts and uploads intermediate CA certificates from ACME.sh fullchain files
- **Complete Trust Chains** - Eliminates the need for `--insecure` flags in client connections
- **Proven Approach** - Uses efficient "certificate + immediate intermediate CA only" method
- **Non-Blocking Operation** - Main certificate deployment continues even if intermediate CA upload fails

### 📝 **Enhanced Certificate Naming**
- **Updated Format** - Changed certificate naming from YYYY-MM-DD to YYYYMMDD format (e.g., `domain.com-20250818`)
- **Consistent Naming** - Main certificates use expiry date, intermediate CAs use Common Name only
- **Consistent Naming** - Naming convention follows established certificate management practices

### 🔧 **New Functions**
- **`extract_immediate_issuing_ca()`** - Extracts immediate issuing CA from fullchain certificate files
- **`get_cert_common_name()`** - Extracts Common Name from certificates for proper naming
- **Step 1.5: Intermediate CA Upload** - New deployment step between certificate upload and service updates

## 🚀 **Key Benefits**

- **Better SSL/TLS Validation** - Clients can properly validate certificate chains without additional configuration
- **Eliminates Insecure Connections** - No more need for `--insecure` flags when connecting to RouterOS
- **Automatic Operation** - Works transparently with existing ACME.sh deployments
- **Backward Compatible** - Existing configurations continue to work unchanged

## 🔧 **Installation**

```bash
# 1. Copy updated script to ACME.sh deploy directory
cp mikrotik.sh ~/.acme.sh/deploy/
chmod +x ~/.acme.sh/deploy/mikrotik.sh

# 2. No configuration changes needed - certificate chain support is automatic
```

## 🚀 **Usage**

Certificate chain support is **completely automatic**. No configuration changes are required:

```bash
# Deploy certificate (now includes automatic intermediate CA upload)
acme.sh --deploy -d example.com --deploy-hook mikrotik

# Debug mode shows certificate chain extraction details
MIKROTIK_LOG_LEVEL=debug acme.sh --deploy -d example.com --deploy-hook mikrotik
```

## 📋 **Example Output**

### New Certificate Chain Upload Process
```
[INFO] Step 1: Uploading certificate files...
[INFO] Certificate uploaded successfully
[INFO] Step 1.5: Checking for intermediate CA certificate...
[INFO] Found intermediate CA: zerossl-ecc-domain-secure-site-ca
[INFO] Uploading intermediate CA certificate...
[INFO] Intermediate CA certificate uploaded successfully: zerossl-ecc-domain-secure-site-ca
[INFO] Step 2: Finding certificate for service updates...
```

### Certificate Naming Examples
- **Main Certificate**: `kiroshi.group-20251112` (domain + expiry date in YYYYMMDD format)
- **Intermediate CA**: `zerossl-ecc-domain-secure-site-ca` (Common Name only)

## 🔍 **Technical Details**

### Certificate Chain Extraction
- **Automatic Detection** - Detects fullchain files provided by ACME.sh
- **Immediate CA Only** - Extracts only the immediate issuing CA (not the full chain)
- **macOS/BSD Compatible** - Works with different awk implementations
- **Error Resilient** - Gracefully handles missing or malformed chain files

### Certificate Upload Process
1. **Step 1**: Upload main certificate and private key
2. **Step 1.5**: Extract and upload intermediate CA certificate (NEW)
3. **Step 2**: Find certificates for service updates
4. **Step 3**: Update RouterOS services
5. **Step 4**: Rename certificates to final names
6. **Step 5-6**: Verify deployment

## 📋 **Requirements**

- **RouterOS**: v7.1+ (REST API support)
- **ACME.sh**: Latest version with fullchain file support
- **System Tools**: `curl`, `base64`, `openssl`, `awk`
- **User Permissions**: RouterOS user with `read,write,api,rest-api` policies

## 🔄 **Migration from v1.1.0**

### Automatic Migration
- **No Configuration Changes** - Certificate chain support is automatic
- **Backward Compatible** - All existing configurations continue to work
- **Enhanced Functionality** - Existing deployments now get certificate chain support

### Certificate Naming Changes
- **Old Format**: `domain.com-2025-11-12` (YYYY-MM-DD)
- **New Format**: `domain.com-20251112` (YYYYMMDD)
- **Impact**: New certificates use updated format, existing certificates remain unchanged

## 🛡️ **Security Enhancements**

- **Complete Trust Chains** - Proper certificate validation without security compromises
- **No Insecure Flags** - Eliminates need for `--insecure` connections
- **Validated Certificates** - All uploaded certificates are verified before deployment
- **Non-Intrusive** - Certificate chain upload doesn't affect main deployment if it fails

## 🔗 **Certificate Chain Benefits**

| Aspect | Without Chain (v1.1.0) | With Chain (v1.2.0) |
|--------|-------------------------|----------------------|
| **Client Validation** | May require `--insecure` | Full validation works |
| **Trust Path** | Incomplete | Complete |
| **Browser Warnings** | Possible certificate warnings | Clean certificate validation |
| **API Connections** | May need insecure flags | Secure connections work |
| **Certificate Store** | Leaf certificate only | Leaf + intermediate CA |

## 📝 **What's Next**

This release establishes complete certificate chain support for MikroTik deployments. Future releases will focus on:
- Certificate chain validation and monitoring
- Enhanced certificate lifecycle management
- Multi-CA environment support

---

**Full Changelog**: See [CHANGELOG.md](CHANGELOG.md) for complete version history.

**Support**: Check the [troubleshooting section](README.md#troubleshooting) for common issues.