# MikroTik RouterOS API Deploy Hook v1.0.0 - First Release

**Release Date**: August 14, 2025
**Version**: 1.0.0
**Status**: Production Ready ✅
**Copyright**: (c) CyB0rgg <dev@bluco.re>

## 🎉 First Release Summary

This is the first stable release of the MikroTik RouterOS API Deploy Hook for ACME.sh. After extensive development, testing, and debugging on live RouterOS systems, the script is now production-ready and fully functional.

## 🚀 What's New

### Core Features
- **REST API Integration** - Complete replacement for SSH/SCP-based certificate deployment
- **Automated Certificate Management** - Upload, import, verify, and deploy SSL certificates
- **Primary Service Integration** - Automatic www-ssl (HTTPS web interface) updates (enabled by default)
- **Optional Services** - Additional api-ssl and hotspot SSL support (disabled by default)
- **Certificate Verification** - Serial number and SHA256 fingerprint validation
- **Smart Naming** - Domain + expiry date certificate naming (e.g., `example.com-2025-11-12`)
- **Comprehensive Logging** - Debug, standard, and quiet modes with detailed output

### Advanced Capabilities
- **Hotspot SSL Support** - Pattern-based hotspot profile certificate updates
- **Connectivity Testing** - API connectivity verification after www-ssl changes
- **Robust Error Handling** - Detailed error messages with troubleshooting guidance
- **Flexible Configuration** - Environment file with multiple search locations
- **Security First** - HTTPS by default, secure credential handling

## 📋 Testing Status

### ✅ Fully Tested Features
- Certificate upload via RouterOS v7.19.4 REST API
- Certificate import and verification system
- Service updates (www-ssl, api-ssl, hotspot profiles)
- Certificate renewal workflow
- Debug and standard logging modes
- ACME.sh deploy hook integration
- Configuration file loading from multiple locations
- Hotspot profile pattern matching
- API connectivity after certificate changes

### 🔧 Technical Validation
- **RouterOS Version**: Tested on v7.19.4 (stable)
- **API Methods**: PUT `/rest/file`, POST `/rest/certificate/import`, PATCH service endpoints
- **Certificate Types**: ECC and RSA certificates
- **File Formats**: PEM certificate and private key files
- **Service Types**: www-ssl, api-ssl, hotspot profiles

## 📊 Real-World Examples

The documentation now includes sanitized real-world examples from actual deployments:

### Debug Mode Output
Shows complete certificate deployment workflow with:
- API connection testing
- Certificate upload and import process
- Serial number and fingerprint verification
- Service updates with connectivity testing
- Final deployment verification

### Standard Mode Output
Clean, production-ready logging showing:
- Step-by-step deployment progress
- Certificate validation results
- Service update confirmations
- Final deployment status

## 🛠️ Installation

### Installation
```bash
git clone https://github.com/your-repo/acme-deploy-mikrotik-api.git
cd acme-deploy-mikrotik-api
cp mikrotik.sh ~/.acme.sh/deploy/
chmod +x ~/.acme.sh/deploy/mikrotik.sh
cp examples/mikrotik.env.example ~/.acme.sh/mikrotik.env
# Edit ~/.acme.sh/mikrotik.env with your RouterOS details
```

## ⚙️ Configuration

### Required Settings
```bash
MIKROTIK_HOST=192.168.1.1
MIKROTIK_USERNAME=admin
MIKROTIK_PASSWORD=your-secure-password
```

### Optional Features
```bash
MIKROTIK_UPDATE_WWW_SSL=true        # HTTPS web interface
MIKROTIK_UPDATE_API_SSL=true        # HTTPS API access
MIKROTIK_UPDATE_HOTSPOT_SSL=true    # Hotspot SSL certificates
MIKROTIK_HOTSPOT_PROFILES="default" # Profile selection
MIKROTIK_LOG_LEVEL=standard         # Logging level
```

## 🔧 Usage

### Basic Deployment
```bash
acme.sh --deploy -d example.com --deploy-hook mikrotik
```

### Debug Mode
```bash
MIKROTIK_LOG_LEVEL=debug acme.sh --deploy -d example.com --deploy-hook mikrotik
```

### Custom Configuration
```bash
MIKROTIK_CONFIG=/path/to/custom.env acme.sh --deploy -d example.com --deploy-hook mikrotik
```

## 🔒 Security Features

- **HTTPS by Default** - Secure API connections on port 443
- **Certificate Validation** - SSL verification with bypass option for testing
- **Secure Credentials** - Environment file storage with restrictive permissions
- **Input Validation** - Comprehensive parameter validation and sanitization
- **No Credential Logging** - Sensitive information excluded from all output

## 📚 Documentation

### Complete Documentation Package
- **README.md** - Comprehensive setup and usage guide
- **CHANGELOG.md** - Detailed version history and changes
- **TECHNICAL_SPECIFICATION.md** - Technical implementation details
- **API_ENDPOINTS.md** - RouterOS API endpoint reference
- **examples/** - Configuration templates and examples

### Key Documentation Sections
- Installation and setup instructions
- RouterOS configuration guide
- Migration from SSH-based methods
- Troubleshooting common issues
- Security best practices
- Real-world usage examples

## 🐛 Known Issues

None - All identified issues during development and testing have been resolved.

## 🔄 Migration from SSH Version

### Old Method
```bash
export ROUTER_OS_HOST="192.168.1.1"
export ROUTER_OS_USERNAME="admin"
export ROUTER_OS_SSH_CMD="ssh -i /path/to/key"
```

### New Method
```bash
# mikrotik.env
MIKROTIK_HOST=192.168.1.1
MIKROTIK_USERNAME=admin
MIKROTIK_PASSWORD=your-password
```

### Benefits
- No SSH key management required
- Better error handling and logging
- More secure API-based authentication
- Support for multiple services

## 🎯 Next Steps

### For Users
1. Install the script using the provided installer
2. Configure your RouterOS connection details
3. Test with a single domain deployment
4. Enable additional services as needed
5. Set up automated certificate renewal

### For Developers
1. Review the comprehensive technical documentation
2. Test with your specific RouterOS configuration
3. Report any issues or feature requests
4. Contribute improvements via pull requests

## 📞 Support

- **Documentation**: Check the troubleshooting section in README.md
- **RouterOS API**: https://help.mikrotik.com/docs/spaces/ROS/pages/47579160/API
- **Issues**: Open an issue on the project repository
- **Community**: Join discussions in the project community

## 🙏 Acknowledgments

- Based on the original ACME.sh RouterOS deploy hook
- Inspired by the FortiGate API deploy hook project structure
- Thanks to the MikroTik community for RouterOS API documentation
- Special thanks to beta testers who provided valuable feedback

---

**Ready for Production** ✅  
This release has been thoroughly tested and is ready for production deployment.