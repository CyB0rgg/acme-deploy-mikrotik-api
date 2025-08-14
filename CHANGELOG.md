# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-08-14

**Copyright (c) CyB0rgg <dev@bluco.re>**

### Added
- **User Permission Documentation** - Comprehensive guide for creating dedicated ACME users with minimal required policies
- **Authentication Troubleshooting** - Step-by-step guide for resolving 401 Unauthorized errors
- **Special Character Password Support** - Improved handling of passwords containing special characters (!@#$%)

### Changed
- **Simplified User Policies** - Reduced required policies to minimal set: `read,write,api,rest-api`
- **Enhanced Documentation** - Added detailed troubleshooting section with common authentication issues
- **Improved Password Handling** - Fixed shell interpretation issues with special characters in passwords

### Removed
- **Certificate Cleanup Functions** - Removed `remove_certificate()` and `cleanup_old_certificates()` functions
- **MIKROTIK_CLEANUP_OLD Configuration** - Removed unnecessary cleanup configuration option
- **MIKROTIK_CERT_NAME_PREFIX Configuration** - Removed redundant certificate naming prefix option

### Fixed
- **Authentication with Special Characters** - Fixed Basic Auth header generation to properly handle special characters
- **Documentation Accuracy** - Corrected all references to removed cleanup functionality

## [1.0.0] - 2025-08-14

**Copyright (c) CyB0rgg <dev@bluco.re>**

### Added
- **Initial Release** - Complete MikroTik RouterOS API deploy hook for ACME.sh
- **REST API Integration** - Uses RouterOS v7.x REST API instead of SSH/SCP for certificate deployment
- **Certificate Management** - Automated upload, import, and verification of SSL certificates
- **Primary Service Support** - Automatic www-ssl (HTTPS web interface) certificate updates (enabled by default)
- **Optional Services** - Additional api-ssl and hotspot SSL service support (disabled by default)
- **Certificate Verification System** - Serial number and SHA256 fingerprint matching for import validation
- **Smart Certificate Naming** - Domain + expiry date format (e.g., `example.com-2025-11-12`)
- **Hotspot SSL Support** - Configurable hotspot profile SSL certificate updates with pattern matching
- **Comprehensive Logging** - Three levels: standard, debug, and quiet with detailed troubleshooting info
- **Environment Configuration** - Flexible `.env` file configuration with multiple search locations
- **Installation Script** - Automated installation with ACME.sh integration verification
- **Security Features** - HTTPS by default, certificate validation, secure credential handling

### Features
- **Configuration Management**: Load settings from `mikrotik.env` file or environment variables
- **API Error Handling**: Parse RouterOS API errors with detailed troubleshooting hints
- **Certificate Lifecycle**: Upload → Import → Verify → Rename → Update Services → Final Verification
- **Service Management**: Updates www-ssl, api-ssl, and hotspot profiles with new certificates
- **Certificate Verification**: Before/after import checks using serial numbers and fingerprints
- **Connectivity Testing**: API connectivity verification after www-ssl certificate changes
- **Pattern Matching**: Flexible hotspot profile selection with wildcards and regex support
- **Robust Error Handling**: Detailed error messages with specific troubleshooting guidance

### Security
- **HTTPS by Default** - Secure API connections on port 443
- **Certificate Validation** - SSL certificate verification (with bypass option for testing)
- **Secure Credentials** - Environment file storage with restrictive permissions
- **Input Validation** - Comprehensive parameter validation and sanitization
- **No Credential Logging** - Sensitive information excluded from debug output

### Documentation
- **Comprehensive README** - Complete setup, usage, and troubleshooting guide
- **Real-world Examples** - Sanitized debug and standard logging output examples
- **RouterOS Setup Guide** - Step-by-step RouterOS configuration instructions
- **Migration Guide** - Easy migration from SSH-based deployment methods
- **API Reference** - Complete list of RouterOS API endpoints used
- **Security Best Practices** - Detailed security recommendations

### Technical Implementation
- **RouterOS v7.19.4 Compatibility** - Tested and optimized for latest RouterOS versions
- **File Upload Method** - Uses PUT `/rest/file` for certificate and key upload
- **Certificate Import** - POST `/rest/certificate/import` with proper file references
- **Service Configuration** - PATCH operations for www-ssl, api-ssl, and hotspot services
- **Certificate Verification** - OpenSSL integration for certificate detail extraction
- **Error Recovery** - Graceful handling of API failures with detailed diagnostics

### Tested Features
- ✅ Certificate upload and import via REST API
- ✅ Serial number and fingerprint verification
- ✅ Service updates (www-ssl, api-ssl, hotspot)
- ✅ Certificate renewal workflow
- ✅ Debug and standard logging modes
- ✅ Configuration file loading from multiple locations
- ✅ ACME.sh deploy hook integration
- ✅ RouterOS v7.19.4 compatibility
- ✅ Hotspot profile pattern matching
- ✅ API connectivity after certificate changes

## [Unreleased]

### Planned
- Support for certificate renewal notifications
- Integration with RouterOS logging system
- Backup and restore functionality for certificates
- Support for custom certificate validation
- Performance optimizations for large certificate deployments
- Multi-router deployment support
- Certificate expiry monitoring and alerts