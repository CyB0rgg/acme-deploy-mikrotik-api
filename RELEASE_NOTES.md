# MikroTik RouterOS API Deploy Hook v1.1.0

**Release Date**: August 14, 2025  
**Copyright**: (c) CyB0rgg <dev@bluco.re>

## 🎯 What's New in v1.1.0

This release focuses on **streamlining the authentication experience** and **removing unnecessary complexity** while maintaining all core certificate deployment functionality.

### 🔐 **Enhanced Authentication**
- **Simplified User Policies** - Reduced required RouterOS policies to minimal set: `read,write,api,rest-api`
- **Fixed Special Character Passwords** - Resolved authentication issues with passwords containing `!@#$%` and other special characters
- **Comprehensive Troubleshooting** - Added step-by-step authentication debugging guide

### 🧹 **Streamlined Configuration**
- **Removed Certificate Cleanup** - Eliminated unnecessary cleanup functions and configuration options
- **Simplified Certificate Naming** - Removed redundant `MIKROTIK_CERT_NAME_PREFIX` configuration
- **Cleaner Script Architecture** - Focused on core certificate deployment functionality

### 📚 **Improved Documentation**
- **User Permission Guide** - Complete instructions for creating dedicated ACME users
- **Authentication Troubleshooting** - Detailed guide for resolving 401 Unauthorized errors
- **Password Best Practices** - Clear guidance for handling special characters in passwords

## 🚀 **Key Features**

- **RouterOS v7.x REST API Integration** - Modern API-based certificate deployment
- **Automated Certificate Management** - Upload, import, verification, and service updates
- **Primary www-ssl Service Support** - HTTPS web interface certificates (enabled by default)
- **Optional Services** - api-ssl and hotspot SSL support (configurable)
- **Certificate Verification** - Serial number and SHA256 fingerprint validation
- **Smart Certificate Naming** - Automatic domain-expiry format (e.g., `example.com-2025-11-12`)
- **Comprehensive Logging** - Debug, standard, and quiet modes

## 🔧 **Installation**

```bash
# 1. Copy script to ACME.sh deploy directory
cp mikrotik.sh ~/.acme.sh/deploy/
chmod +x ~/.acme.sh/deploy/mikrotik.sh

# 2. Create configuration file
cp examples/mikrotik.env.example ~/.acme.sh/mikrotik.env
chmod 600 ~/.acme.sh/mikrotik.env

# 3. Configure RouterOS connection details
nano ~/.acme.sh/mikrotik.env
```

## ⚙️ **Configuration**

### Required Settings
```bash
# RouterOS Connection Details
MIKROTIK_HOST=192.168.1.1
MIKROTIK_USERNAME=admin
MIKROTIK_PASSWORD="your-secure-password"  # Use quotes for special characters
```

### RouterOS User Setup
```bash
# Create dedicated ACME user (recommended)
/user group add name=acme-deploy policy=read,write,api,rest-api
/user add name=acme-user password=secure-password group=acme-deploy
```

## 🚀 **Usage**

```bash
# Deploy certificate
acme.sh --deploy -d example.com --deploy-hook mikrotik

# Debug mode
MIKROTIK_LOG_LEVEL=debug acme.sh --deploy -d example.com --deploy-hook mikrotik
```

## 🔍 **Troubleshooting Authentication**

### 401 Unauthorized Error
1. **Test with admin user first** to verify script functionality
2. **Check user group permissions**: `/user print detail where name=your-username`
3. **Verify REST API access**: `curl -k -u "username:password" https://router/rest/system/resource`
4. **Create dedicated ACME user** with correct policies: `read,write,api,rest-api`

### Password Issues
- **Always use quotes** for passwords with special characters: `MIKROTIK_PASSWORD="pass!@#$%"`
- **Test with simple password first** to verify user account works
- **Check shell escaping** if using complex passwords

## 📋 **Requirements**

- **RouterOS**: v7.1+ (REST API support)
- **ACME.sh**: Latest version
- **System Tools**: `curl`, `base64`, `openssl` (optional for verification)
- **User Permissions**: RouterOS user with `read,write,api,rest-api` policies

## 🔄 **Migration from v1.0.0**

### Removed Configuration Options
- `MIKROTIK_CLEANUP_OLD` - No longer needed (cleanup functions removed)
- `MIKROTIK_CERT_NAME_PREFIX` - No longer needed (automatic naming)

### Updated User Policies
Old (v1.0.0):
```bash
policy=api,read,write,policy,test,password,sensitive,romon
```

New (v1.1.0):
```bash
policy=read,write,api,rest-api
```

## 🛡️ **Security**

- **HTTPS by Default** - Secure API connections
- **Minimal User Privileges** - Reduced required RouterOS policies
- **Secure Credential Storage** - Environment file with restrictive permissions
- **Certificate Validation** - Automatic verification of uploaded certificates

## 🔗 **Comparison with SSH-based Methods**

| Feature | REST API (This Script) | SSH/SCP Methods |
|---------|------------------------|-----------------|
| **Security** | HTTPS API authentication | SSH key management |
| **Setup** | Simple user configuration | SSH key generation/deployment |
| **Compatibility** | RouterOS v7.1+ | All RouterOS versions |
| **Performance** | Fast API calls | File transfer overhead |
| **Debugging** | Detailed API error messages | Limited SSH output |
| **Maintenance** | No SSH key rotation needed | Regular key management |

## 📝 **What's Next**

This release establishes a solid, streamlined foundation for MikroTik certificate deployment. Future releases will focus on:
- Additional service support based on user feedback
- Enhanced certificate validation features
- Performance optimizations

---

**Full Changelog**: See [CHANGELOG.md](CHANGELOG.md) for complete version history.

**Support**: Check the [troubleshooting section](README.md#troubleshooting) for common issues.