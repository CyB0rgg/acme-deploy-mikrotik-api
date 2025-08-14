# MikroTik RouterOS API Deploy Hook for ACME.sh

**Copyright (c) CyB0rgg <dev@bluco.re>**

A modern ACME.sh deploy hook that uses the MikroTik RouterOS REST API instead of SSH/SCP for automated certificate deployment.

## 🚨 Critical: The Shift to 47-Day TLS Certificates

**The CA/Browser Forum has approved a significant change to TLS certificate lifetimes, reducing them to just 47 days by March 2029.** This decision marks a pivotal shift in digital certificate management, emphasizing the need for robust automation to handle increased renewal frequency.

**Timeline for Implementation** ([source](https://trustandidentity.jiscinvolve.org/wp/2025/06/10/the-shift-to-47-day-tls-certs-why-it-matters/)):
- **15 March 2026**: Maximum certificate lifetime drops to 200 days
- **15 September 2027**: Certificate lifetime further reduces to 100 days
- **15 March 2029**: Final certificate lifetime reaches 47 days

**Why 47 Days?**
The 47-day period is designed to align with practical renewal cycles and ensure certificates are always based on up-to-date information. Shorter lifespans contribute to reducing the risk of compromised private keys, domain hijacking, and mis-issued certificates.

**Impact on Certificate Management:**
- **Renewal Frequency**: Certificates will need renewal approximately every 6 weeks by 2029
- **Automation Imperative**: Manual certificate management becomes completely impractical
- **Service Continuity**: Automated deployment is essential to prevent service disruptions
- **Infrastructure Requirements**: Organizations must adopt automation to manage frequent renewals efficiently

**This Tool's Solution:**
This automated deployment hook ensures your MikroTik RouterOS devices are prepared for the future of certificate management. By integrating with ACME.sh's automated renewal process, your certificates will be seamlessly renewed and deployed regardless of their validity period - whether it's today's 90 days or tomorrow's 47 days.

## Features

- 🔐 **REST API Based** - Uses RouterOS REST API instead of SSH/SCP
- 🛡️ **Secure** - HTTPS by default with certificate validation
- ⚙️ **Configurable** - Environment file configuration following established patterns
- 🔧 **Service Management** - Updates www-ssl, api-ssl, and other services
- 📝 **Comprehensive Logging** - Debug, standard, and quiet log levels
- ❌ **Error Handling** - Detailed error messages with troubleshooting hints

## Requirements

- RouterOS v7.x or newer with REST API enabled
- `curl` command (standard on most systems)
- `base64` command (standard on most systems)
- ACME.sh certificate management tool

## Installation

```bash
# 1. Download the script
git clone https://github.com/your-repo/acme-deploy-mikrotik-api.git
cd acme-deploy-mikrotik-api

# 2. Install as ACME.sh deploy hook (REQUIRED LOCATION)
cp mikrotik.sh ~/.acme.sh/deploy/
chmod +x ~/.acme.sh/deploy/mikrotik.sh

# 3. Create configuration file
cp examples/mikrotik.env.example ~/.acme.sh/mikrotik.env
chmod 600 ~/.acme.sh/mikrotik.env

# 4. Verify installation
ls -la ~/.acme.sh/deploy/mikrotik.sh
```

**Important**: ACME.sh only recognizes deploy hooks in the `~/.acme.sh/deploy/` directory.

### Configure the Script

Edit the configuration file with your RouterOS details:

```bash
nano ~/.acme.sh/mikrotik.env
```

## Configuration

### Required Settings

Create and edit `~/.acme.sh/mikrotik.env` with your RouterOS connection details:

```bash
# Required: RouterOS Connection Details
MIKROTIK_HOST=192.168.1.1
MIKROTIK_USERNAME=admin
MIKROTIK_PASSWORD=your-secure-password
```

### Default Service Configuration

```bash
# Default: Primary Service (automatically enabled)
MIKROTIK_UPDATE_WWW_SSL=true        # HTTPS web interface (default: enabled)

# Optional: Additional Services (true/false)
MIKROTIK_UPDATE_API_SSL=false       # HTTPS API access (default: disabled)
MIKROTIK_UPDATE_HOTSPOT_SSL=false   # Hotspot SSL certificate (default: disabled)
```

### Optional Settings

```bash
# Optional: Connection Settings
MIKROTIK_PORT=443                    # 443 for HTTPS, 80 for HTTP
MIKROTIK_INSECURE=false             # Allow insecure HTTPS connections

MIKROTIK_TIMEOUT=30                 # API call timeout in seconds

# Optional: Hotspot Profile Configuration
MIKROTIK_HOTSPOT_PROFILES="default" # Comma-separated list or regex pattern
                                    # Examples: "default,guest" or "corporate-*" or ".*"

# Optional: Logging
MIKROTIK_LOG_LEVEL=standard         # standard, debug, quiet
```

**Note**: The script's primary purpose is updating the www-ssl service certificate for HTTPS web interface access. This is enabled by default. Additional services (api-ssl, hotspot) are optional and disabled by default.

## Usage

### Basic Usage

```bash
# Deploy certificate for a domain
acme.sh --deploy -d example.com --deploy-hook mikrotik
```

### Advanced Usage

```bash
# Use custom configuration file
MIKROTIK_CONFIG=/path/to/custom.env acme.sh --deploy -d example.com --deploy-hook mikrotik

# Enable debug logging
MIKROTIK_LOG_LEVEL=debug acme.sh --deploy -d example.com --deploy-hook mikrotik

# Quiet mode (errors only)
MIKROTIK_LOG_LEVEL=quiet acme.sh --deploy -d example.com --deploy-hook mikrotik

# Deploy to specific services only
# Edit ~/.acme.sh/mikrotik.env to enable/disable specific services:
# MIKROTIK_UPDATE_WWW_SSL=true    # Default: enabled (primary purpose)
# MIKROTIK_UPDATE_API_SSL=false   # Optional: disabled by default
# MIKROTIK_UPDATE_HOTSPOT_SSL=false # Optional: disabled by default

# Configure hotspot profiles to update:
# MIKROTIK_HOTSPOT_PROFILES="default"           # Single profile
# MIKROTIK_HOTSPOT_PROFILES="default,guest"     # Multiple profiles
# MIKROTIK_HOTSPOT_PROFILES="corporate-*"       # Pattern matching
# MIKROTIK_HOTSPOT_PROFILES=".*"                # All profiles (regex)
```

## RouterOS Setup

### 1. Enable REST API Service

```routeros
# Enable HTTPS service (recommended)
/ip service enable www-ssl
/ip service set www-ssl port=443

# Or enable HTTP service (not recommended for production)
/ip service enable www
/ip service set www port=80
```

### 2. Create API User (Recommended)

Create a dedicated user for certificate management:

```routeros
# Create user group with minimal permissions
/user group add name=acme-cert policy=api,read,write,test

# Create user for ACME certificate deployment
/user add name=acme-deploy group=acme-cert password=secure-password
```

### 3. Configure Firewall (If Needed)

Allow API access from your ACME.sh server:

```routeros
# Allow HTTPS API access
/ip firewall filter add chain=input protocol=tcp dst-port=443 src-address=YOUR.ACME.SERVER.IP action=accept

# Or allow HTTP API access (not recommended)
/ip firewall filter add chain=input protocol=tcp dst-port=80 src-address=YOUR.ACME.SERVER.IP action=accept
```

### 4. Configure Hotspot Profiles (If Using Hotspot SSL)

If you're using the hotspot SSL certificate feature, you can configure which profiles to update:

```bash
# Single profile
MIKROTIK_HOTSPOT_PROFILES="default"

# Multiple specific profiles
MIKROTIK_HOTSPOT_PROFILES="default,guest,corporate"

# Pattern matching with wildcards
MIKROTIK_HOTSPOT_PROFILES="guest-*"        # Matches: guest-wifi, guest-temp, etc.
MIKROTIK_HOTSPOT_PROFILES="corporate-*"    # Matches: corporate-main, corporate-guest, etc.

# All profiles (use with caution)
MIKROTIK_HOTSPOT_PROFILES=".*"
```

**Pattern Matching Examples:**
- `"default"` - Updates only the "default" profile
- `"guest-*"` - Updates all profiles starting with "guest-"
- `"*-ssl"` - Updates all profiles ending with "-ssl"
- `".*"` - Updates all hotspot profiles (regex for all)
- `"profile1,profile2"` - Updates specific named profiles

## Migration from SSH Version

### Old SSH Method

```bash
export ROUTER_OS_HOST="192.168.1.1"
export ROUTER_OS_USERNAME="admin"
export ROUTER_OS_SSH_CMD="ssh -i /path/to/key"
export ROUTER_OS_SCP_CMD="scp -i /path/to/key"
```

### New API Method

```bash
# mikrotik.env file
MIKROTIK_HOST=192.168.1.1
MIKROTIK_USERNAME=admin
MIKROTIK_PASSWORD=your-password
```

**Benefits of Migration:**
- No SSH key management required
- Better error handling and logging
- More secure API-based authentication
- Support for multiple services

## Troubleshooting

### Installation Issues

**Problem**: `Error encountered while deploying` with usage message shown
**Cause**: Configuration file not found or missing required parameters
**Solution**:
```bash
# Check if mikrotik.env exists in the preferred location:
ls -la ~/.acme.sh/mikrotik.env         # Preferred: ACME.sh directory

# Alternative locations (fallback):
ls -la ~/mikrotik.env                  # Home directory
ls -la mikrotik.env                    # Current directory

# Create configuration file (preferred location):
cp examples/mikrotik.env.example ~/.acme.sh/mikrotik.env

# Edit with your RouterOS details:
nano ~/.acme.sh/mikrotik.env
```

**Problem**: `Configuration failed. Required: MIKROTIK_HOST, MIKROTIK_USERNAME, MIKROTIK_PASSWORD`
**Solution**: Ensure all required parameters are set in `~/.acme.sh/mikrotik.env`

### Common Issues

#### Connection Failed
```
[ERROR] Connection failed: Cannot connect to 192.168.1.1:443
```
**Solutions:**
- Check if RouterOS device is reachable: `ping 192.168.1.1`
- Verify REST API service is enabled: `/ip service print`
- Check firewall rules allow API access
- Verify correct port (443 for HTTPS, 80 for HTTP)

#### Authentication Failed
```
[ERROR] Unauthorized: Invalid username or password
```
**Solutions:**
- Verify username and password in `mikrotik.env`
- Check user exists: `/user print`
- Verify user has API permissions: `/user group print`

#### Certificate Upload Failed
```
[ERROR] Bad Request: Invalid parameters or JSON format
```
**Solutions:**
- Check certificate file exists and is readable
- Verify certificate format (PEM format required)
- Check available disk space on RouterOS device

#### Service Update Failed
```
[WARN] Failed to update api-ssl service
```
**Solutions:**
- Check if service exists: `/ip service print`
- Verify service is enabled
- Check user permissions for service management

### Debug Mode

Enable debug logging for detailed troubleshooting:

```bash
MIKROTIK_LOG_LEVEL=debug acme.sh --deploy -d example.com --deploy-hook mikrotik
```

Debug mode shows:
- Configuration loading details
- API request/response details
- Certificate encoding information
- Service update attempts

### Example Output

#### Debug Mode Output

```bash
MIKROTIK_LOG_LEVEL=debug acme.sh --deploy -d example.com --deploy-hook mikrotik
```

```
[INFO] Starting MikroTik certificate deployment for domain: example.com
[DEBUG] Configuration loaded: Host=192.168.1.100, Port=443, User=admin
[INFO] Testing API connection to 192.168.1.100:443...
[WARN] Using insecure HTTPS connection (certificate validation disabled)
[DEBUG] API Call: GET https://192.168.1.100:443/rest/system/resource
[DEBUG] HTTP Status: 200
[DEBUG] Response Body: {"architecture-name":"x86_64","board-name":"CHR","build-time":"2025-07-28 10:00:16","cpu":"Common","cpu-count":"1","cpu-frequency":"2099","cpu-load":"0","factory-software":"7.1","free-hdd-space":"17019092992","free-memory":"819691520","platform":"MikroTik","total-hdd-space":"17040297984","total-memory":"1073741824","uptime":"7h17m52s","version":"7.19.4 (stable)","write-sect-since-reboot":"15160","write-sect-total":"15160"}
[INFO] API connection successful
[DEBUG] RouterOS system info: {"version":"7.19.4 (stable)","platform":"MikroTik"}
[INFO] Step 0: Checking current certificates...
[DEBUG] API Call: GET https://192.168.1.100:443/rest/certificate?common-name=example.com
[DEBUG] HTTP Status: 200
[INFO] Current certificate for example.com: example.com-2025-11-12 (Valid, expires: 2025-11-13 00:59:59)
[DEBUG] Certificate details: ID=*F, Name=example.com-2025-11-12, Status=Valid, Expires=2025-11-13 00:59:59
[DEBUG] Using certificate file (not fullchain): /root/.acme.sh/example.com_ecc/example.com.cer
[DEBUG] Final certificate name with expiry: example.com-2025-11-12
[INFO] Step 1: Uploading certificate files...
[INFO] Uploading certificate 'temp-example.com-1755176013'...
[DEBUG] Certificate file: /root/.acme.sh/example.com_ecc/example.com.cer
[DEBUG] Private key file: /root/.acme.sh/example.com_ecc/example.com.key
[DEBUG] Certificate upload via RouterOS file system method
[DEBUG] Uploading certificate file to RouterOS filesystem...
[DEBUG] API Call: PUT https://192.168.1.100:443/rest/file
[DEBUG] HTTP Status: 201
[DEBUG] Response Body: {".id":"*802001E","contents":"-----BEGIN CERTIFICATE-----\r\nMIIEKjCCA7CgAwIBAgIQNPXVhCJeggtEn3d7N9OyKDAKBggqhkjOPQQDAzBLMQsw\r\n[... certificate content truncated ...]\r\n-----END CERTIFICATE-----\r\n","last-modified":"2025-08-14 13:53:32","name":"temp-example.com-1755176013.cer","size":"1530","type":".cer file"}
[DEBUG] Certificate file uploaded successfully
[DEBUG] Uploading private key file to RouterOS filesystem...
[DEBUG] API Call: PUT https://192.168.1.100:443/rest/file
[DEBUG] HTTP Status: 201
[DEBUG] Response Body: {".id":"*802003C","contents":"-----BEGIN EC PRIVATE KEY-----\r\n[... private key content truncated ...]\r\n-----END EC PRIVATE KEY-----\r\n","last-modified":"2025-08-14 13:53:32","name":"temp-example.com-1755176013.key","size":"294","type":".key file"}
[DEBUG] Private key file uploaded successfully
[DEBUG] Extracting certificate details from file for verification...
[DEBUG] Certificate file serial number: 34f5d584225e820b449f777b37d3b228
[DEBUG] Certificate file fingerprint: 1471913213f2a7deb41cffaf3c474e1c8092e3973911f11bb95173686773e9e5
[DEBUG] Importing certificate from uploaded files...
[DEBUG] API Call: POST https://192.168.1.100:443/rest/certificate/import
[DEBUG] HTTP Status: 200
[DEBUG] Certificate import response: [{"certificates-imported":"1","decryption-failures":"0","files-imported":"0","keys-with-no-certificate":"0","private-keys-imported":"0"}]
[DEBUG] API Call: POST https://192.168.1.100:443/rest/certificate/import
[DEBUG] HTTP Status: 200
[DEBUG] Private key import response: [{"certificates-imported":"0","decryption-failures":"0","files-imported":"1","keys-with-no-certificate":"0","private-keys-imported":"1"}]
[DEBUG] Verifying certificate import by serial number and fingerprint...
[DEBUG] API Call: GET https://192.168.1.100:443/rest/certificate?common-name=example.com
[DEBUG] HTTP Status: 200
[DEBUG] RouterOS certificate serial number: 34f5d584225e820b449f777b37d3b228
[DEBUG] RouterOS certificate fingerprint: 1471913213f2a7deb41cffaf3c474e1c8092e3973911f11bb95173686773e9e5
[INFO] Certificate import verification successful - serial and fingerprint match
[DEBUG] File serial: 34f5d584225e820b449f777b37d3b228, RouterOS serial: 34f5d584225e820b449f777b37d3b228
[DEBUG] File fingerprint: 1471913213f2a7deb41cffaf3c474e1c8092e3973911f11bb95173686773e9e5, RouterOS fingerprint: 1471913213f2a7deb41cffaf3c474e1c8092e3973911f11bb95173686773e9e5
[INFO] Certificate uploaded successfully
[INFO] Step 2: Finding certificate for service updates...
[DEBUG] API Call: GET https://192.168.1.100:443/rest/certificate?common-name=example.com
[DEBUG] HTTP Status: 200
[DEBUG] Found certificate with ID: *F
[INFO] Step 3: Updating services...
[DEBUG] Using certificate name for service updates: example.com-2025-11-12
[INFO] Updating www-ssl service certificate...
[DEBUG] API Call: GET https://192.168.1.100:443/rest/ip/service
[DEBUG] HTTP Status: 200
[DEBUG] Found service www-ssl with ID: *6
[DEBUG] API Call: PATCH https://192.168.1.100:443/rest/ip/service/*6
[DEBUG] HTTP Status: 200
[DEBUG] Response Body: {".id":"*6","address":"","certificate":"example.com-2025-11-12","disabled":"false","dynamic":"false","invalid":"false","max-sessions":"20","name":"www-ssl","port":"443","proto":"tcp","tls-version":"any","vrf":"main"}
[INFO] www-ssl service updated successfully
[DEBUG] Testing API connectivity after certificate change...
[DEBUG] API Call: GET https://192.168.1.100:443/rest/system/resource
[DEBUG] HTTP Status: 200
[INFO] API connectivity confirmed after certificate change
[INFO] Updating api-ssl service certificate...
[DEBUG] Found service api-ssl with ID: *9
[DEBUG] API Call: PATCH https://192.168.1.100:443/rest/ip/service/*9
[DEBUG] HTTP Status: 200
[INFO] api-ssl service updated successfully
[INFO] Updating hotspot SSL certificates...
[DEBUG] Listing hotspot profiles...
[DEBUG] API Call: GET https://192.168.1.100:443/rest/ip/hotspot/profile
[DEBUG] HTTP Status: 200
[INFO] Updating hotspot profile 'default' SSL certificate...
[DEBUG] Found hotspot profile default with ID: *2
[DEBUG] API Call: PATCH https://192.168.1.100:443/rest/ip/hotspot/profile/*2
[DEBUG] HTTP Status: 200
[INFO] Hotspot profile 'default' SSL certificate updated successfully
[INFO] Updated SSL certificates for 1 hotspot profile(s)
[INFO] Step 4: Renaming certificate to final name...
[DEBUG] Renaming certificate ID *F to: example.com-2025-11-12
[DEBUG] API Call: PATCH https://192.168.1.100:443/rest/certificate/*F
[DEBUG] HTTP Status: 200
[INFO] Certificate renamed to: example.com-2025-11-12
[INFO] Step 5: Verifying service certificate assignments...
[DEBUG] Verifying www-ssl service is using certificate: example.com-2025-11-12
[DEBUG] www-ssl service correctly using certificate: example.com-2025-11-12
[DEBUG] Verifying api-ssl service is using certificate: example.com-2025-11-12
[DEBUG] api-ssl service correctly using certificate: example.com-2025-11-12
[INFO] Step 6: Verifying final certificate deployment...
[DEBUG] API Call: GET https://192.168.1.100:443/rest/certificate?common-name=example.com
[DEBUG] HTTP Status: 200
[INFO] New certificate deployed: example.com-2025-11-12 (Valid, expires: 2025-11-13 00:59:59)
[DEBUG] Final certificate details: ID=*F, Name=example.com-2025-11-12, Status=Valid, Expires=2025-11-13 00:59:59
[INFO] Certificate deployment completed successfully!
[INFO] 3 service(s) updated with certificate: example.com-2025-11-12
[Thu Aug 14 13:53:36 BST 2025] Success
```

#### Standard Mode Output

```bash
acme.sh --deploy -d example.com --deploy-hook mikrotik
```

```
[INFO] Starting MikroTik certificate deployment for domain: example.com
[INFO] Testing API connection to 192.168.1.100:443...
[WARN] Using insecure HTTPS connection (certificate validation disabled)
[INFO] API connection successful
[INFO] Step 0: Checking current certificates...
[INFO] Current certificate for example.com: example.com-2025-11-12 (Valid, expires: 2025-11-13 00:59:59)
[INFO] Step 1: Uploading certificate files...
[INFO] Uploading certificate 'temp-example.com-1755177316'...
[INFO] Certificate import verification successful - serial and fingerprint match
[INFO] Certificate uploaded successfully
[INFO] Step 2: Finding certificate for service updates...
[INFO] Step 3: Updating services...
[INFO] Updating www-ssl service certificate...
[INFO] www-ssl service updated successfully
[INFO] API connectivity confirmed after certificate change
[INFO] Updating api-ssl service certificate...
[INFO] api-ssl service updated successfully
[INFO] Updating hotspot SSL certificates...
[INFO] Updating hotspot profile 'default' SSL certificate...
[INFO] Hotspot profile 'default' SSL certificate updated successfully
[INFO] Updated SSL certificates for 1 hotspot profile(s)
[INFO] Step 4: Renaming certificate to final name...
[INFO] Certificate renamed to: example.com-2025-11-12
[INFO] Step 5: Verifying service certificate assignments...
[INFO] Step 6: Verifying final certificate deployment...
[INFO] New certificate deployed: example.com-2025-11-12 (Valid, expires: 2025-11-13 00:59:59)
[INFO] Certificate deployment completed successfully!
[INFO] 3 service(s) updated with certificate: example.com-2025-11-12
[Thu Aug 14 14:15:19 BST 2025] Success
```

### Testing Connection

Test API connectivity manually:

```bash
# Test with curl (replace with your details)
curl -k -u "admin:password" "https://192.168.1.1/rest/system/resource"
```

## Security Considerations

### 1. Use HTTPS
- Always use HTTPS (port 443) in production
- Only use HTTP (port 80) for testing with `MIKROTIK_INSECURE=true`

### 2. Secure Credentials
- Use strong passwords for RouterOS API users
- Set restrictive file permissions on `mikrotik.env`: `chmod 600 mikrotik.env`
- Never commit actual credentials to version control

### 3. Network Security
- Restrict API access to specific source IPs in firewall
- Use dedicated API user with minimal required permissions
- Consider VPN access for remote certificate deployment

### 4. Certificate Security
- Certificates are automatically validated before upload
- Old certificates are cleaned up automatically
- Certificate/key matching is verified

## API Endpoints Used

| Operation | Method | Endpoint | Purpose |
|-----------|--------|----------|---------|
| Test Connection | GET | `/rest/system/resource` | Verify API access |
| Import Certificate | POST | `/rest/certificate/import` | Upload cert/key |
| List Certificates | GET | `/rest/certificate` | Find existing certs |
| Remove Certificate | DELETE | `/rest/certificate/{id}` | Clean up old certs |
| Update WWW-SSL | PATCH | `/rest/ip/service/www-ssl` | Configure HTTPS |
| Update API-SSL | PATCH | `/rest/ip/service/api-ssl` | Configure API HTTPS |
| Update Hotspot SSL | PATCH | `/rest/ip/hotspot/profile/default` | Configure Hotspot SSL |

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with actual RouterOS devices
5. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and changes.

## Support

- Check [troubleshooting section](#troubleshooting) for common issues
- Review RouterOS API documentation: https://help.mikrotik.com/docs/spaces/ROS/pages/47579160/API
- Open an issue for bugs or feature requests

## Acknowledgments

- Based on the original ACME.sh RouterOS deploy hook
- Inspired by the FortiGate API deploy hook project structure
- Thanks to the MikroTik community for RouterOS API documentation