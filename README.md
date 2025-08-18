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
- 🔗 **Certificate Chain Support** - Automatically uploads intermediate CA certificates for complete trust chains
- 📝 **Comprehensive Logging** - Debug, standard, and quiet log levels
- ❌ **Error Handling** - Detailed error messages with troubleshooting hints

## Certificate Chain Support

This deploy hook now includes **automatic intermediate CA certificate upload** to ensure complete certificate trust chains on your MikroTik RouterOS device. This eliminates SSL/TLS validation issues that can occur when only leaf certificates are deployed.

### How It Works

1. **Automatic Detection** - When a fullchain certificate file is provided by ACME.sh, the script automatically extracts the immediate issuing CA certificate
2. **Intelligent Upload** - The intermediate CA is uploaded as a separate certificate with proper naming (e.g., `zerossl-ecc-domain-secure-site-ca`)
3. **Non-Blocking Operation** - If intermediate CA upload fails, the main certificate deployment continues normally
4. **Proven Approach** - Uses the efficient "certificate + immediate intermediate CA only" method for optimal compatibility

### Benefits

- **Complete Trust Chains** - Eliminates the need for `--insecure` flags in client connections
- **Better SSL/TLS Validation** - Clients can properly validate certificate chains without additional configuration
- **Automatic Operation** - No additional configuration required - works transparently with existing setups
- **Backward Compatible** - Existing deployments continue to work unchanged

### Certificate Naming

Certificates are now named using the YYYYMMDD format for consistency:
- **Main Certificate**: `domain.com-20250818` (expires date)
- **Intermediate CA**: `zerossl-ecc-domain-secure-site-ca` (Common Name only)

### Example Output with Certificate Chain

```
[INFO] Step 1: Uploading certificate files...
[INFO] Certificate uploaded successfully
[INFO] Step 1.5: Checking for intermediate CA certificate...
[INFO] Found intermediate CA: zerossl-ecc-domain-secure-site-ca
[INFO] Uploading intermediate CA certificate...
[INFO] Intermediate CA certificate uploaded successfully: zerossl-ecc-domain-secure-site-ca
```

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
MIKROTIK_PASSWORD="your-secure-password"  # Use quotes for passwords with special characters (!@#$%)
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

### User Permissions

The RouterOS user must have sufficient privileges for REST API access and certificate management:

#### Required User Groups
For certificate deployment, the user needs to be in one of these groups:
- `full` - Full administrative access (recommended for testing)
- `write` - Write access to system resources
- Custom group with specific policies (see below)

#### Custom User Group Setup
If you don't want to use the `admin` user, create a dedicated user with minimal required permissions:

```bash
# In RouterOS terminal/Winbox:
/user group add name=acme-deploy policy=read,write,api,rest-api

# Create dedicated user
/user add name=acme-user password=your-secure-password group=acme-deploy

# Verify user permissions
/user print detail where name=acme-user
```

#### Required Policies
The user group must have these policies enabled:
- `read` - Read system information
- `write` - Modify certificates and services
- `api` - REST API access
- `rest-api` - REST API functionality

#### Troubleshooting Authentication
1. **Test with admin user first** to verify script functionality
2. **Check user group**: `/user print detail where name=your-username`
3. **Verify API access**: Try accessing `https://your-router/rest/system/resource` in browser
4. **Check RouterOS version**: REST API requires RouterOS v7.1+

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
- Automatic certificate chain support

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
- Certificate chain extraction and upload details

### Example Output

#### Standard Mode Output with Certificate Chain

```bash
acme.sh --deploy -d kiroshi.group --deploy-hook mikrotik
```

```
[INFO] Starting MikroTik certificate deployment for domain: kiroshi.group
[INFO] Testing API connection to mikrotik.kiroshi.group:443...
[INFO] API connection successful
[INFO] Step 0: Checking current certificates...
[INFO] Current certificate for kiroshi.group: kiroshi.group.cer_0 (Valid, expires: 2025-11-13 00:59:59)
[INFO] Step 1: Uploading certificate files...
[INFO] Uploading certificate 'temp-kiroshi.group-1755501335'...
[INFO] Certificate import verification successful - serial and fingerprint match
[INFO] Certificate uploaded successfully
[INFO] Step 1.5: Checking for intermediate CA certificate...
[INFO] Found intermediate CA: zerossl-ecc-domain-secure-site-ca
[INFO] Uploading intermediate CA certificate...
[INFO] Intermediate CA certificate uploaded successfully: zerossl-ecc-domain-secure-site-ca
[INFO] Step 2: Finding certificate for service updates...
[INFO] Step 3: Updating services...
[INFO] Updating www-ssl service certificate...
[INFO] www-ssl service updated successfully
[INFO] API connectivity confirmed after certificate change
[INFO] Updating hotspot SSL certificates...
[INFO] Updating hotspot profile 'hsprof1' SSL certificate...
[INFO] Hotspot profile 'hsprof1' SSL certificate updated successfully
[INFO] Updated SSL certificates for 1 hotspot profile(s)
[INFO] Step 4: Renaming certificate to final name...
[INFO] Certificate renamed to: kiroshi.group-20251112
[INFO] Step 5: Verifying service certificate assignments...
[INFO] Step 6: Verifying final certificate deployment...
[INFO] New certificate deployed: kiroshi.group-20251112 (Valid, expires: 2025-11-13 00:59:59)
[INFO] Certificate deployment completed successfully!
[INFO] 2 service(s) updated with certificate: kiroshi.group-20251112
[Mon Aug 18 08:15:38 BST 2025] Success
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
- Certificate/key matching is verified
- Intermediate CA certificates are automatically included for complete trust chains

## API Endpoints Used

| Operation | Method | Endpoint | Purpose |
|-----------|--------|----------|---------|
| Test Connection | GET | `/rest/system/resource` | Verify API access |
| Upload Files | PUT | `/rest/file` | Upload cert/key/CA files |
| Import Certificate | POST | `/rest/certificate/import` | Import cert/key/CA |
| List Certificates | GET | `/rest/certificate` | Find existing certs |
| Update WWW-SSL | PATCH | `/rest/ip/service/www-ssl` | Configure HTTPS |
| Update API-SSL | PATCH | `/rest/ip/service/api-ssl` | Configure API HTTPS |
| Update Hotspot SSL | PATCH | `/rest/ip/hotspot/profile/default` | Configure Hotspot SSL |

## Troubleshooting

### Authentication Issues

#### 401 Unauthorized Error
1. **Test with admin user first**:
   ```bash
   MIKROTIK_USERNAME=admin MIKROTIK_PASSWORD=admin-password acme.sh --deploy -d example.com --deploy-hook mikrotik
   ```

2. **Check user group permissions**:
   ```bash
   # In RouterOS terminal:
   /user print detail where name=your-username
   ```

3. **Verify REST API access**:
   ```bash
   # Test direct API access:
   curl -k -u "username:password" https://your-router:443/rest/system/resource
   ```

4. **Create dedicated ACME user** (recommended):
   ```bash
   # In RouterOS terminal:
   /user group add name=acme-deploy policy=read,write,api,rest-api
   /user add name=acme-user password=secure-password group=acme-deploy
   ```

#### Password with Special Characters
- **Always use quotes**: `MIKROTIK_PASSWORD="pass!@#$%"`
- **Test simple password first**: Verify user works with basic password
- **Check shell escaping**: Some shells may require additional escaping

### Common Issues

#### Certificate Upload Fails
- **Check file permissions**: Ensure certificate and key files are readable
- **Verify certificate format**: RouterOS expects PEM format
- **Check certificate validity**: Use `openssl x509 -in cert.pem -text -noout`

#### API Connection Issues
- **Test connectivity**: `curl -k https://your-router:443/rest/system/resource`
- **Check RouterOS version**: REST API requires v7.1+
- **Verify HTTPS service**: Ensure www-ssl service is enabled and running

#### Service Update Failures
- **Check service names**: Use `/ip service print` in RouterOS terminal
- **Verify certificate exists**: Check certificate was imported successfully
- **Review service configuration**: Some services may have additional requirements

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