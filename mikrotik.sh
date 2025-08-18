#!/usr/bin/env bash

# MikroTik RouterOS API Deploy Hook for ACME.sh
# Uses RouterOS REST API instead of SSH/SCP for certificate deployment
#
# Copyright (c) CyB0rgg <dev@bluco.re>
# License: MIT
# Version: 1.1.0

# Exit on any error
set -e

# Global variables
MIKROTIK_CONFIG_FILE=""
MIKROTIK_HOST=""
MIKROTIK_USERNAME=""
MIKROTIK_PASSWORD=""
MIKROTIK_PORT="443"
MIKROTIK_INSECURE="false"
MIKROTIK_TIMEOUT="30"
MIKROTIK_UPDATE_WWW_SSL="true"
MIKROTIK_UPDATE_API_SSL="false"
MIKROTIK_UPDATE_HOTSPOT_SSL="false"
MIKROTIK_HOTSPOT_PROFILES="default"
MIKROTIK_LOG_LEVEL="standard"

# Logging functions
_info() {
  if [ "$MIKROTIK_LOG_LEVEL" != "quiet" ]; then
    echo "[INFO] $1" >&2
  fi
}

_debug() {
  if [ "$MIKROTIK_LOG_LEVEL" = "debug" ]; then
    echo "[DEBUG] $1" >&2
  fi
}

_err() {
  echo "[ERROR] $1" >&2
}

_err_exit() {
  echo "[ERROR] $1" >&2
  exit 1
}

_warn() {
  if [ "$MIKROTIK_LOG_LEVEL" != "quiet" ]; then
    echo "[WARN] $1" >&2
  fi
}

# Load configuration from .env file
load_config() {
  local config_file="${MIKROTIK_CONFIG:-mikrotik.env}"
  
  # Try multiple locations for the config file
  local config_paths=(
    "$config_file"                    # Current directory
    "$HOME/$config_file"              # Home directory
    "$HOME/.acme.sh/$config_file"     # ACME.sh directory
    "$(dirname "$0")/$config_file"    # Same directory as script
  )
  
  local found_config=""
  for path in "${config_paths[@]}"; do
    if [ -f "$path" ]; then
      found_config="$path"
      break
    fi
  done
  
  if [ -n "$found_config" ]; then
    _debug "Loading configuration from $found_config"
    # Source the config file safely
    set -a
    # shellcheck source=/dev/null
    . "$found_config"
    set +a
    MIKROTIK_CONFIG_FILE="$found_config"
  else
    _debug "No config file found in any of these locations: ${config_paths[*]}"
    _debug "Using environment variables only"
  fi
  
  # Validate required parameters - but don't exit during load_config
  # Let the main function handle missing config gracefully
  if [ -z "$MIKROTIK_HOST" ] || [ -z "$MIKROTIK_USERNAME" ] || [ -z "$MIKROTIK_PASSWORD" ]; then
    _debug "Missing required configuration parameters"
    return 1
  fi
  
  # Set defaults for optional parameters
  MIKROTIK_PORT="${MIKROTIK_PORT:-443}"
  MIKROTIK_INSECURE="${MIKROTIK_INSECURE:-false}"
  MIKROTIK_TIMEOUT="${MIKROTIK_TIMEOUT:-30}"
  MIKROTIK_UPDATE_WWW_SSL="${MIKROTIK_UPDATE_WWW_SSL:-true}"
  MIKROTIK_UPDATE_API_SSL="${MIKROTIK_UPDATE_API_SSL:-false}"
  MIKROTIK_UPDATE_HOTSPOT_SSL="${MIKROTIK_UPDATE_HOTSPOT_SSL:-false}"
  MIKROTIK_HOTSPOT_PROFILES="${MIKROTIK_HOTSPOT_PROFILES:-default}"
  MIKROTIK_LOG_LEVEL="${MIKROTIK_LOG_LEVEL:-standard}"
  
  _debug "Configuration loaded: Host=$MIKROTIK_HOST, Port=$MIKROTIK_PORT, User=$MIKROTIK_USERNAME"
}

# Construct base URL for API calls
get_base_url() {
  local protocol="https"
  if [ "$MIKROTIK_PORT" = "80" ]; then
    protocol="http"
  fi
  echo "${protocol}://${MIKROTIK_HOST}:${MIKROTIK_PORT}/rest"
}

# Generic API call function
api_call() {
  local method="$1"
  local endpoint="$2"
  local data="$3"
  local base_url
  base_url=$(get_base_url)
  local url="${base_url}${endpoint}"
  
  _debug "API Call: $method $url"
  
  # Prepare curl options
  local curl_opts=()
  curl_opts+=("-s")  # Silent
  curl_opts+=("-w" "%{http_code}")  # Write HTTP status code
  curl_opts+=("-X" "$method")
  curl_opts+=("-H" "Content-Type: application/json")
  curl_opts+=("-H" "Authorization: Basic $(printf '%s:%s' "$MIKROTIK_USERNAME" "$MIKROTIK_PASSWORD" | base64)")
  curl_opts+=("--connect-timeout" "$MIKROTIK_TIMEOUT")
  curl_opts+=("--max-time" "$((MIKROTIK_TIMEOUT * 2))")
  
  # Handle insecure connections
  if [ "$MIKROTIK_INSECURE" = "true" ]; then
    curl_opts+=("-k")
  fi
  
  # Add data for POST/PATCH requests
  if [ -n "$data" ]; then
    curl_opts+=("-d" "$data")
  fi
  
  # Make the API call
  local response
  response=$(curl "${curl_opts[@]}" "$url" 2>/dev/null)
  
  # Extract HTTP status code (last 3 characters)
  local status_code="${response: -3}"
  local body="${response%???}"
  
  _debug "HTTP Status: $status_code"
  # Only show response body for non-certificate API calls to avoid dumping cert store
  if [[ "$endpoint" != "/certificate"* ]]; then
    _debug "Response Body: $body"
  fi
  
  # Handle HTTP status codes
  case "$status_code" in
    200|201|204)
      echo "$body"
      return 0
      ;;
    400)
      # Check if it's a "file already exists" error
      if echo "$body" | grep -q "file already exists"; then
        _debug "File already exists - will attempt to overwrite"
        echo "$body"
        return 2  # Special return code for file exists
      else
        _err "Bad Request: Invalid parameters or JSON format. Check certificate data and API endpoint."
        return 1
      fi
      ;;
    401)
      _err "Unauthorized: Invalid username or password. Check MIKROTIK_USERNAME and MIKROTIK_PASSWORD in $MIKROTIK_CONFIG_FILE"
      return 1
      ;;
    403)
      _err "Forbidden: User '$MIKROTIK_USERNAME' lacks API permissions for certificate management."
      return 1
      ;;
    404)
      _err "Not Found: API endpoint not available. Check MIKROTIK_HOST ($MIKROTIK_HOST) and RouterOS version."
      return 1
      ;;
    409)
      _err "Conflict: Certificate name already exists. Use different certificate name."
      return 1
      ;;
    500)
      local error_msg
      error_msg=$(echo "$body" | grep -o '"error":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "Internal server error")
      _err "RouterOS Error: $error_msg"
      return 1
      ;;
    000)
      _err "Connection failed: Cannot connect to $MIKROTIK_HOST:$MIKROTIK_PORT. Check host, port, and network connectivity."
      return 1
      ;;
    *)
      _err "Unexpected HTTP status: $status_code. Response: $body"
      return 1
      ;;
  esac
}

# Test API connection and credentials
test_connection() {
  _info "Testing API connection to $MIKROTIK_HOST:$MIKROTIK_PORT..."
  
  # Show insecure warning once during connection test
  if [ "$MIKROTIK_INSECURE" = "true" ]; then
    _warn "Using insecure HTTPS connection (certificate validation disabled)"
  fi
  
  local response
  if response=$(api_call "GET" "/system/resource" ""); then
    _info "API connection successful"
    _debug "RouterOS system info: $response"
    return 0
  else
    _err "API connection test failed"
    return 1
  fi
}

# Encode certificate or key file to base64
encode_cert_file() {
  local file_path="$1"
  local file_type="$2"
  
  if [ ! -f "$file_path" ]; then
    _err "$file_type file not found: $file_path"
    return 1
  fi
  
  _debug "Encoding $file_type file: $file_path"
  
  # Use base64 command (available on most systems)
  if command -v base64 >/dev/null 2>&1; then
    base64 -w 0 < "$file_path" 2>/dev/null || base64 < "$file_path" 2>/dev/null
  else
    _err "base64 command not found. Please install base64 utility."
    return 1
  fi
}

# Upload certificate using RouterOS v7.19.4 REST API file upload method
upload_certificate_files() {
  local cert_name="$1"
  local cert_file="$2"
  local key_file="$3"
  local base_url
  base_url=$(get_base_url)
  
  _debug "Certificate upload via RouterOS file system method"
  
  # Validate files exist and are readable
  if [ ! -f "$cert_file" ]; then
    _err "Certificate file not found: $cert_file"
    return 1
  fi
  
  if [ ! -f "$key_file" ]; then
    _err "Private key file not found: $key_file"
    return 1
  fi
  
  if [ ! -r "$cert_file" ]; then
    _err "Certificate file not readable: $cert_file"
    return 1
  fi
  
  if [ ! -r "$key_file" ]; then
    _err "Private key file not readable: $key_file"
    return 1
  fi
  
  # Step 1: Upload certificate file to RouterOS files
  _debug "Uploading certificate file to RouterOS filesystem..."
  local cert_contents
  cert_contents=$(cat "$cert_file" | sed 's/$/\\r\\n/' | tr -d '\n')
  local cert_filename="${cert_name}.cer"
  
  local cert_json_payload
  cert_json_payload=$(printf '{"name":"%s","contents":"%s"}' "$cert_filename" "$cert_contents")
  
  local cert_response
  cert_response=$(api_call "PUT" "/file" "$cert_json_payload")
  local cert_result=$?
  
  if [ $cert_result -eq 2 ]; then
    # File exists, try to remove it first
    _debug "Certificate file exists, removing old file..."
    api_call "DELETE" "/file/$cert_filename" "" >/dev/null 2>&1 || true
    
    # Try upload again
    if ! cert_response=$(api_call "PUT" "/file" "$cert_json_payload"); then
      _err "Failed to upload certificate file to RouterOS filesystem after removing old file"
      return 1
    fi
  elif [ $cert_result -ne 0 ]; then
    _err "Failed to upload certificate file to RouterOS filesystem"
    return 1
  fi
  
  _debug "Certificate file uploaded successfully"
  
  # Step 2: Upload private key file to RouterOS files
  _debug "Uploading private key file to RouterOS filesystem..."
  local key_contents
  key_contents=$(cat "$key_file" | sed 's/$/\\r\\n/' | tr -d '\n')
  local key_filename="${cert_name}.key"
  
  local key_json_payload
  key_json_payload=$(printf '{"name":"%s","contents":"%s"}' "$key_filename" "$key_contents")
  
  local key_response
  key_response=$(api_call "PUT" "/file" "$key_json_payload")
  local key_result=$?
  
  if [ $key_result -eq 2 ]; then
    # File exists, try to remove it first
    _debug "Private key file exists, removing old file..."
    api_call "DELETE" "/file/$key_filename" "" >/dev/null 2>&1 || true
    
    # Try upload again
    if ! key_response=$(api_call "PUT" "/file" "$key_json_payload"); then
      _err "Failed to upload private key file to RouterOS filesystem after removing old file"
      return 1
    fi
  elif [ $key_result -ne 0 ]; then
    _err "Failed to upload private key file to RouterOS filesystem"
    return 1
  fi
  
  _debug "Private key file uploaded successfully"
  
  # Step 3: Extract serial number and fingerprint from certificate file for verification
  _debug "Extracting certificate details from file for verification..."
  local file_serial="" file_fingerprint=""
  
  if command -v openssl >/dev/null 2>&1; then
    # Get certificate serial number from file (remove colons and convert to lowercase)
    file_serial=$(openssl x509 -in "$cert_file" -noout -serial 2>/dev/null | cut -d= -f2 | tr -d ':' | tr '[:upper:]' '[:lower:]')
    
    # Get certificate fingerprint from file (SHA256, remove colons and convert to lowercase)
    file_fingerprint=$(openssl x509 -in "$cert_file" -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2 | tr -d ':' | tr '[:upper:]' '[:lower:]')
    
    _debug "Certificate file serial number: $file_serial"
    _debug "Certificate file fingerprint: $file_fingerprint"
  else
    _warn "openssl not available - cannot verify certificate details"
  fi
  
  # Step 4: Import certificate from uploaded files
  _debug "Importing certificate from uploaded files..."
  
  # First import the certificate
  local cert_import_payload
  cert_import_payload=$(printf '{"file-name":"%s","passphrase":""}' "$cert_filename")
  
  local cert_import_response
  if ! cert_import_response=$(api_call "POST" "/certificate/import" "$cert_import_payload"); then
    _err "Failed to import certificate file"
    return 1
  fi
  
  _debug "Certificate import response: $cert_import_response"
  
  # Then import the private key to join with certificate
  local key_import_payload
  key_import_payload=$(printf '{"file-name":"%s","passphrase":""}' "$key_filename")
  
  local key_import_response
  if ! key_import_response=$(api_call "POST" "/certificate/import" "$key_import_payload"); then
    _err "Failed to import private key file"
    return 1
  fi
  
  _debug "Private key import response: $key_import_response"
  
  # Step 5: Verify certificate import by checking if RouterOS has certificate with matching serial and fingerprint
  if [ -n "$file_serial" ] && [ -n "$file_fingerprint" ]; then
    _debug "Verifying certificate import by serial number and fingerprint..."
    
    # Use targeted API call to find certificate with specific common name (use domain, not temp name)
    local domain_cert_response
    domain_cert_response=$(api_call "GET" "/certificate?common-name=$domain" "")
    
    if [ -n "$domain_cert_response" ] && [ "$domain_cert_response" != "[]" ]; then
      # Extract serial number and fingerprint from RouterOS certificate
      local routeros_serial routeros_fingerprint
      routeros_serial=$(echo "$domain_cert_response" | grep -o '"serial-number":"[^"]*"' | cut -d'"' -f4 | tr -d ':' | tr '[:upper:]' '[:lower:]')
      routeros_fingerprint=$(echo "$domain_cert_response" | grep -o '"fingerprint":"[^"]*"' | cut -d'"' -f4 | tr -d ':' | tr '[:upper:]' '[:lower:]')
      
      _debug "RouterOS certificate serial number: $routeros_serial"
      _debug "RouterOS certificate fingerprint: $routeros_fingerprint"
      
      if [ "$file_serial" = "$routeros_serial" ] && [ "$file_fingerprint" = "$routeros_fingerprint" ]; then
        _info "Certificate import verification successful - serial and fingerprint match"
        _debug "File serial: $file_serial, RouterOS serial: $routeros_serial"
        _debug "File fingerprint: $file_fingerprint, RouterOS fingerprint: $routeros_fingerprint"
        return 0
      else
        _warn "Certificate import verification failed - serial or fingerprint mismatch"
        _debug "File serial: $file_serial, RouterOS serial: $routeros_serial"
        _debug "File fingerprint: $file_fingerprint, RouterOS fingerprint: $routeros_fingerprint"
        return 0  # Continue anyway as certificate may still be imported
      fi
    else
      _warn "Certificate verification failed - no certificate found for domain: $domain"
      return 0  # Continue anyway
    fi
  else
    _warn "Cannot verify certificate import - missing serial number or fingerprint"
    return 0  # Continue anyway
  fi
}

# Get certificate details by name pattern
get_certificate_details() {
  local cert_name_pattern="$1"
  
  _debug "Getting certificate details for pattern: $cert_name_pattern"
  
  local response
  if response=$(api_call "GET" "/certificate" ""); then
    # Find certificate matching the pattern and extract details
    echo "$response" | grep -o '"[^"]*":"[^"]*"[^}]*"name":"[^"]*'$cert_name_pattern'[^"]*"[^}]*' | head -1
  else
    _err "Failed to get certificate details"
    return 1
  fi
}

# Extract Common Name from certificate
get_cert_common_name() {
  local cert_file="$1"
  if command -v openssl >/dev/null 2>&1; then
    local cn=$(openssl x509 -in "$cert_file" -noout -subject 2>/dev/null | \
      sed -n 's/.*CN[[:space:]]*=[[:space:]]*\([^,]*\).*/\1/p' | \
      tr ' ' '-' | tr '[:upper:]' '[:lower:]' | \
      sed 's/[^a-zA-Z0-9.-]//g')
    
    if [ -n "$cn" ]; then
      echo "$cn"
    else
      echo "cert-$(date +%s)"
    fi
  else
    echo "cert-$(date +%s)"
  fi
}

# Extract immediate issuing CA (the certificate directly above the leaf)
extract_immediate_issuing_ca() {
  local fullchain_file="$1"
  local temp_dir=$(mktemp -d)
  
  _debug "Extracting immediate issuing CA from: $fullchain_file"
  
  # Copy fullchain to temp directory
  cp "$fullchain_file" "$temp_dir/fullchain.pem"
  cd "$temp_dir"
  
  # Split certificates using awk
  awk '
  /-----BEGIN CERTIFICATE-----/ {
    cert_num++;
    in_cert = 1;
    cert_content = $0 "\n";
    next;
  }
  in_cert {
    cert_content = cert_content $0 "\n";
    if (/-----END CERTIFICATE-----/) {
      filename = "cert_" sprintf("%02d", cert_num);
      print cert_content > filename;
      close(filename);
      in_cert = 0;
      cert_content = "";
    }
  }
  ' "fullchain.pem"
  
  # Count certificates
  local cert_files=(cert_*)
  local cert_count=${#cert_files[@]}
  
  _debug "Found $cert_count certificate(s) in fullchain"
  
  if [ "$cert_count" -gt 1 ]; then
    # The immediate issuing CA is the second certificate (cert_02)
    local issuing_ca_file="cert_02"
    if [ -f "$issuing_ca_file" ] && [ -s "$issuing_ca_file" ]; then
      # Copy to a permanent location
      local perm_file="$temp_dir/immediate_issuing_ca.pem"
      cp "$issuing_ca_file" "$perm_file"
      
      # Get the Common Name for this CA
      local ca_common_name
      if command -v openssl >/dev/null 2>&1; then
        ca_common_name=$(openssl x509 -in "$perm_file" -noout -subject 2>/dev/null | \
          sed -n 's/.*CN[[:space:]]*=[[:space:]]*\([^,]*\).*/\1/p' | \
          tr ' ' '-' | tr '[:upper:]' '[:lower:]' | \
          sed 's/[^a-zA-Z0-9.-]//g')
        
        if [ -z "$ca_common_name" ]; then
          ca_common_name="intermediate-ca-$(date +%s)"
        fi
      else
        ca_common_name="intermediate-ca-$(date +%s)"
      fi
      
      _debug "Immediate issuing CA found with CN: $ca_common_name"
      
      cd - >/dev/null
      echo "$perm_file|$ca_common_name|$temp_dir"
      return 0
    fi
  fi
  
  cd - >/dev/null
  rm -rf "$temp_dir"
  _debug "No immediate issuing CA found"
  return 1
}

# Verify certificate import by checking certificate details
verify_certificate_import() {
  local cert_name="$1"
  
  _debug "Verifying certificate import for: $cert_name"
  
  local cert_details
  if cert_details=$(get_certificate_details "$cert_name"); then
    if [ -n "$cert_details" ]; then
      _debug "Certificate verification successful: $cert_details"
      return 0
    else
      _debug "Certificate not found in certificate store"
      return 1
    fi
  else
    _debug "Failed to retrieve certificate details"
    return 1
  fi
}

# Test API connectivity after certificate change
test_connectivity_after_cert_change() {
  _debug "Testing API connectivity after certificate change..."
  
  # Give RouterOS a moment to apply the certificate change
  sleep 2
  
  local response
  if response=$(api_call "GET" "/system/resource" ""); then
    _info "API connectivity confirmed after certificate change"
    return 0
  else
    _warn "API connectivity lost after certificate change"
    return 1
  fi
}

# Upload certificate and private key
upload_certificate() {
  local cert_name="$1"
  local cert_file="$2"
  local key_file="$3"
  
  _info "Uploading certificate '$cert_name'..."
  
  # Verify files exist
  if [ ! -f "$cert_file" ]; then
    _err "Certificate file not found: $cert_file"
    return 1
  fi
  
  if [ ! -f "$key_file" ]; then
    _err "Private key file not found: $key_file"
    return 1
  fi
  
  _debug "Certificate file: $cert_file"
  _debug "Private key file: $key_file"
  
  # Upload certificate using multipart form data
  local response
  if response=$(upload_certificate_files "$cert_name" "$cert_file" "$key_file"); then
    _info "Certificate uploaded successfully"
    return 0
  else
    _err "Failed to upload certificate"
    return 1
  fi
}

# List certificates matching naming pattern
list_certificates() {
  local name_pattern="$1"
  
  _debug "Listing certificates matching pattern: $name_pattern"
  
  local response
  if response=$(api_call "GET" "/certificate" ""); then
    # Parse JSON response to find matching certificates - no debug output
    echo "$response" | grep -o '"\.id":"[^"]*"[^}]*"name":"[^"]*"' | \
      grep "\"name\":\"$name_pattern" | \
      grep -o '"\.id":"[^"]*"' | \
      cut -d'"' -f4
  else
    _err "Failed to list certificates"
    return 1
  fi
}


# Update service certificate
update_service() {
  local service_name="$1"
  local cert_name="$2"
  
  _info "Updating $service_name service certificate..."
  
  # First get the service ID
  local response
  if ! response=$(api_call "GET" "/ip/service" ""); then
    _warn "Failed to get service list for $service_name"
    return 1
  fi
  
  # Extract service ID for the specific service (take first match only)
  local service_id
  service_id=$(echo "$response" | grep -o '"\.id":"[^"]*"[^}]*"name":"'$service_name'"' | grep -o '"\.id":"[^"]*"' | cut -d'"' -f4 | head -1)
  
  if [ -z "$service_id" ]; then
    _warn "Service $service_name not found"
    return 1
  fi
  
  _debug "Found service $service_name with ID: $service_id"
  
  local json_payload
  json_payload=$(printf '{"certificate":"%s"}' "$cert_name")
  
  if api_call "PATCH" "/ip/service/$service_id" "$json_payload" >/dev/null; then
    _info "$service_name service updated successfully"
    return 0
  else
    _warn "Failed to update $service_name service"
    return 1
  fi
}

# List hotspot profiles
list_hotspot_profiles() {
  _debug "Listing hotspot profiles..."
  
  local response
  if response=$(api_call "GET" "/ip/hotspot/profile" ""); then
    # Parse JSON response to extract profile names
    echo "$response" | grep -o '"name":"[^"]*"' | cut -d'"' -f4
  else
    _err "Failed to list hotspot profiles"
    return 1
  fi
}

# Update hotspot certificate for a specific profile
update_hotspot_profile() {
  local profile_name="$1"
  local cert_name="$2"
  
  _info "Updating hotspot profile '$profile_name' SSL certificate..."
  
  # First get the profile ID
  local response
  if ! response=$(api_call "GET" "/ip/hotspot/profile" ""); then
    _warn "Failed to get hotspot profile list"
    return 1
  fi
  
  # Extract profile ID for the specific profile (take first match only)
  local profile_id
  profile_id=$(echo "$response" | grep -o '"\.id":"[^"]*"[^}]*"name":"'$profile_name'"' | grep -o '"\.id":"[^"]*"' | cut -d'"' -f4 | head -1)
  
  if [ -z "$profile_id" ]; then
    _warn "Hotspot profile $profile_name not found"
    return 1
  fi
  
  _debug "Found hotspot profile $profile_name with ID: $profile_id"
  
  local json_payload
  json_payload=$(printf '{"ssl-certificate":"%s"}' "$cert_name")
  
  if api_call "PATCH" "/ip/hotspot/profile/$profile_id" "$json_payload" >/dev/null; then
    _info "Hotspot profile '$profile_name' SSL certificate updated successfully"
    return 0
  else
    _warn "Failed to update hotspot profile '$profile_name' SSL certificate"
    return 1
  fi
}

# Update hotspot certificates for configured profiles
update_hotspot_certificates() {
  local cert_name="$1"
  
  if [ -z "$MIKROTIK_HOTSPOT_PROFILES" ]; then
    _debug "No hotspot profiles configured"
    return 0
  fi
  
  _info "Updating hotspot SSL certificates..."
  
  # Get list of all hotspot profiles
  local all_profiles
  all_profiles=$(list_hotspot_profiles)
  
  if [ -z "$all_profiles" ]; then
    _warn "No hotspot profiles found on RouterOS device"
    return 1
  fi
  
  local updated_count=0
  
  # Check if MIKROTIK_HOTSPOT_PROFILES contains comma-separated list or pattern
  if echo "$MIKROTIK_HOTSPOT_PROFILES" | grep -q ","; then
    # Handle comma-separated list
    local IFS=','
    for profile_pattern in $MIKROTIK_HOTSPOT_PROFILES; do
      profile_pattern=$(echo "$profile_pattern" | tr -d ' ')  # Remove whitespace
      
      # Check each profile against the pattern
      while IFS= read -r profile_name; do
        if [ -n "$profile_name" ]; then
          # Simple pattern matching (supports * wildcards)
          if echo "$profile_name" | grep -q "^${profile_pattern//\*/.*}$"; then
            if update_hotspot_profile "$profile_name" "$cert_name"; then
              updated_count=$((updated_count + 1))
            fi
          fi
        fi
      done <<< "$all_profiles"
    done
  else
    # Handle single pattern or regex
    local profile_pattern="$MIKROTIK_HOTSPOT_PROFILES"
    
    # Check each profile against the pattern
    while IFS= read -r profile_name; do
      if [ -n "$profile_name" ]; then
        # Simple pattern matching (supports * wildcards and regex)
        if echo "$profile_name" | grep -q "^${profile_pattern//\*/.*}$"; then
          if update_hotspot_profile "$profile_name" "$cert_name"; then
            updated_count=$((updated_count + 1))
          fi
        fi
      fi
    done <<< "$all_profiles"
  fi
  
  if [ "$updated_count" -gt 0 ]; then
    _info "Updated SSL certificates for $updated_count hotspot profile(s)"
  else
    _warn "No hotspot profiles matched pattern: $MIKROTIK_HOTSPOT_PROFILES"
  fi
}


# List current certificates for the specific domain
list_current_certificates() {
  local domain="$1"
  
  local response
  if response=$(api_call "GET" "/certificate?common-name=$domain" ""); then
    if [ -n "$response" ] && [ "$response" != "[]" ]; then
      local cert_name=$(echo "$response" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
      local cert_expiry=$(echo "$response" | grep -o '"invalid-after":"[^"]*"' | cut -d'"' -f4)
      local cert_expires_after=$(echo "$response" | grep -o '"expires-after":"[^"]*"' | cut -d'"' -f4)
      local cert_id=$(echo "$response" | grep -o '"\.id":"[^"]*"' | cut -d'"' -f4)
      
      # Determine if certificate is valid or expired
      local status="Valid"
      if echo "$cert_expires_after" | grep -q "^-"; then
        status="EXPIRED"
      fi
      
      _info "Current certificate for $domain: $cert_name ($status, expires: $cert_expiry)"
      _debug "Certificate details: ID=$cert_id, Name=$cert_name, Status=$status, Expires=$cert_expiry"
    else
      _info "No existing certificate found for domain: $domain"
      _debug "No certificate found matching common-name: $domain"
    fi
  else
    _warn "Failed to check existing certificates"
    return 1
  fi
}

# Get certificate ID by name pattern
get_certificate_id() {
  local cert_name_pattern="$1"
  
  _debug "Getting certificate ID for pattern: $cert_name_pattern"
  
  local response
  if response=$(api_call "GET" "/certificate" ""); then
    # Find certificate matching the pattern and extract ID
    echo "$response" | grep -o '"\.id":"[^"]*"[^}]*"name":"[^"]*'$cert_name_pattern'[^"]*"[^}]*' | grep -o '"\.id":"[^"]*"' | cut -d'"' -f4 | head -1
  else
    _err "Failed to get certificate ID"
    return 1
  fi
}

# Get certificate by subject (Common Name)
get_certificate_by_subject() {
  local domain="$1"
  
  _debug "Getting certificate by subject/domain: $domain"
  
  local response
  if response=$(api_call "GET" "/certificate" ""); then
    # Find certificate with matching subject (CN=domain)
    echo "$response" | grep -o '"\.id":"[^"]*"[^}]*"subject":"[^"]*CN='$domain'[^"]*"[^}]*"name":"[^"]*"' | head -1
  else
    _err "Failed to get certificate by subject"
    return 1
  fi
}

# Rename certificate by ID
rename_certificate() {
  local cert_id="$1"
  local new_name="$2"
  
  _debug "Renaming certificate ID $cert_id to: $new_name"
  
  local json_payload
  json_payload=$(printf '{"name":"%s"}' "$new_name")
  
  if api_call "PATCH" "/certificate/$cert_id" "$json_payload" >/dev/null; then
    _info "Certificate renamed to: $new_name"
    return 0
  else
    _warn "Failed to rename certificate to: $new_name"
    return 1
  fi
}

# Verify service is using correct certificate name
verify_service_certificate() {
  local service_name="$1"
  local expected_cert_name="$2"
  
  _debug "Verifying $service_name service is using certificate: $expected_cert_name"
  
  # Get service configuration
  local response
  if ! response=$(api_call "GET" "/ip/service" ""); then
    _warn "Failed to get service list for verification"
    return 1
  fi
  
  # Extract certificate name for the specific service (take first match only)
  local current_cert
  current_cert=$(echo "$response" | grep '"name":"'$service_name'"' | grep -o '"certificate":"[^"]*"' | cut -d'"' -f4 | head -1)
  
  if [ "$current_cert" = "$expected_cert_name" ]; then
    _debug "$service_name service correctly using certificate: $current_cert"
    return 0
  else
    _warn "$service_name service using certificate '$current_cert', expected '$expected_cert_name'"
    return 1
  fi
}

# Main deployment function
mikrotik_deploy() {
  local domain="$1"
  local key_file="$2"
  local cert_file="$3"
  local ca_file="$4"
  local fullchain_file="$5"
  
  _info "Starting MikroTik certificate deployment for domain: $domain"
  
  # Load configuration
  if ! load_config; then
    _err_exit "Configuration failed. Required: MIKROTIK_HOST, MIKROTIK_USERNAME, MIKROTIK_PASSWORD
Set them in mikrotik.env file or environment variables.
Config file search locations:
  - mikrotik.env (current directory)
  - ~/mikrotik.env (home directory)
  - ~/.acme.sh/mikrotik.env (ACME.sh directory)
  - Same directory as script"
  fi
  
  # Test API connection
  if ! test_connection; then
    _err_exit "API connection test failed. Cannot proceed with deployment."
  fi
  
  # Step 0: Check current certificates before making changes
  _info "Step 0: Checking current certificates..."
  list_current_certificates "$domain"
  
  # Always use the certificate file (not fullchain) for RouterOS
  # RouterOS expects individual certificate files, not certificate chains
  local cert_to_upload="$cert_file"
  _debug "Using certificate file (not fullchain): $cert_to_upload"
  
  # Extract certificate expiry date for final naming
  local cert_expiry=""
  if command -v openssl >/dev/null 2>&1 && [ -f "$cert_to_upload" ]; then
    cert_expiry=$(openssl x509 -in "$cert_to_upload" -noout -enddate 2>/dev/null | cut -d= -f2)
    if [ -n "$cert_expiry" ]; then
      # Convert to YYYYMMDD format (matching FortiGate approach)
      cert_expiry=$(date -d "$cert_expiry" "+%Y%m%d" 2>/dev/null || echo "")
    fi
  fi
  
  # Generate final certificate name with expiry date
  local final_cert_name="${domain}-${cert_expiry}"
  _debug "Final certificate name: $final_cert_name"
  
  # Step 1: Upload certificate with temporary name (RouterOS will assign default name)
  local temp_cert_name="temp-${domain}-$(date +%s)"
  _info "Step 1: Uploading certificate files..."
  if ! upload_certificate "$temp_cert_name" "$cert_to_upload" "$key_file"; then
    _err_exit "Certificate upload failed. Cannot proceed with service updates."
  fi
  
  # Step 1.5: Upload intermediate CA certificate if available (FortiGate approach)
  _info "Step 1.5: Checking for intermediate CA certificate..."
  local ca_result=""
  if [ -f "$fullchain_file" ]; then
    local ca_info
    if ca_info=$(extract_immediate_issuing_ca "$fullchain_file"); then
      local ca_file=$(echo "$ca_info" | cut -d'|' -f1)
      local ca_common_name=$(echo "$ca_info" | cut -d'|' -f2)
      local ca_temp_dir=$(echo "$ca_info" | cut -d'|' -f3)
      
      _info "Found intermediate CA: $ca_common_name"
      _debug "CA file: $ca_file"
      
      # Generate CA certificate name using only Common Name (no date suffix for CA certs)
      local ca_cert_name="${ca_common_name}"
      _debug "CA certificate name: $ca_cert_name"
      
      # Upload intermediate CA certificate (no private key needed for CA)
      _info "Uploading intermediate CA certificate..."
      local ca_base_url
      ca_base_url=$(get_base_url)
      
      # Upload CA certificate file to RouterOS files
      _debug "Uploading CA certificate file to RouterOS filesystem..."
      local ca_contents
      ca_contents=$(cat "$ca_file" | sed 's/$/\\r\\n/' | tr -d '\n')
      local ca_filename="${ca_cert_name}.cer"
      
      local ca_json_payload
      ca_json_payload=$(printf '{"name":"%s","contents":"%s"}' "$ca_filename" "$ca_contents")
      
      local ca_response
      ca_response=$(api_call "PUT" "/file" "$ca_json_payload")
      local ca_upload_result=$?
      
      if [ $ca_upload_result -eq 2 ]; then
        # File exists, try to remove it first
        _debug "CA certificate file exists, removing old file..."
        api_call "DELETE" "/file/$ca_filename" "" >/dev/null 2>&1 || true
        
        # Try upload again
        if ! ca_response=$(api_call "PUT" "/file" "$ca_json_payload"); then
          _warn "Failed to upload CA certificate file to RouterOS filesystem after removing old file"
          ca_result="failed"
        else
          _debug "CA certificate file uploaded successfully"
        fi
      elif [ $ca_upload_result -ne 0 ]; then
        _warn "Failed to upload CA certificate file to RouterOS filesystem"
        ca_result="failed"
      else
        _debug "CA certificate file uploaded successfully"
      fi
      
      # Import CA certificate if upload succeeded
      if [ "$ca_result" != "failed" ]; then
        _debug "Importing CA certificate from uploaded file..."
        local ca_import_payload
        ca_import_payload=$(printf '{"file-name":"%s","name":"%s","passphrase":""}' "$ca_filename" "$ca_cert_name")
        
        local ca_import_response
        if ! ca_import_response=$(api_call "POST" "/certificate/import" "$ca_import_payload"); then
          _warn "Failed to import CA certificate file"
          ca_result="failed"
        else
          _info "Intermediate CA certificate uploaded successfully: $ca_cert_name"
          _debug "CA import response: $ca_import_response"
          ca_result="success"
        fi
      fi
      
      # Clean up temporary directory
      rm -rf "$ca_temp_dir" 2>/dev/null || true
    else
      _debug "No intermediate CA found in fullchain file"
    fi
  else
    _debug "No fullchain file provided, skipping intermediate CA upload"
  fi
  
  # Step 2: Find the certificate (use existing one since verification passed)
  _info "Step 2: Finding certificate for service updates..."
  local imported_cert_id
  
  # Since verification passed, we know the certificate exists - get its ID
  local cert_response
  cert_response=$(api_call "GET" "/certificate?common-name=$domain" "")
  
  if [ -n "$cert_response" ] && [ "$cert_response" != "[]" ]; then
    imported_cert_id=$(echo "$cert_response" | grep -o '"\.id":"[^"]*"' | cut -d'"' -f4 | head -1)
    _debug "Found certificate with ID: $imported_cert_id"
  else
    _err_exit "Could not find certificate for domain: $domain"
  fi
  
  # Step 3: Update services to use the new certificate
  _info "Step 3: Updating services..."
  local services_updated=0
  local services_failed=0
  
  # Get the certificate name from the certificate we already found and verified
  local current_cert_name
  current_cert_name=$(echo "$cert_response" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | head -1)
  
  if [ -z "$current_cert_name" ]; then
    _err_exit "Could not determine current certificate name for service updates"
  fi
  
  _debug "Using certificate name for service updates: $current_cert_name"
  
  # Update www-ssl service (HTTPS web interface) - do this first
  if [ "$MIKROTIK_UPDATE_WWW_SSL" = "true" ]; then
    if update_service "www-ssl" "$current_cert_name"; then
      services_updated=$((services_updated + 1))
      # Test connectivity after www-ssl update
      if ! test_connectivity_after_cert_change; then
        _warn "API connectivity issue after www-ssl update, but continuing..."
      fi
    else
      services_failed=$((services_failed + 1))
    fi
  fi
  
  # Update api-ssl service (HTTPS API access)
  if [ "$MIKROTIK_UPDATE_API_SSL" = "true" ]; then
    if update_service "api-ssl" "$current_cert_name"; then
      services_updated=$((services_updated + 1))
    else
      services_failed=$((services_failed + 1))
    fi
  fi
  
  # Update hotspot SSL certificates
  if [ "$MIKROTIK_UPDATE_HOTSPOT_SSL" = "true" ]; then
    if update_hotspot_certificates "$current_cert_name"; then
      services_updated=$((services_updated + 1))
    else
      services_failed=$((services_failed + 1))
    fi
  fi
  
  # Step 4: Rename certificate to final name
  _info "Step 4: Renaming certificate to final name..."
  if ! rename_certificate "$imported_cert_id" "$final_cert_name"; then
    _warn "Certificate rename failed, but services are updated with working certificate"
  fi
  
  # Step 5: Verify all services are using the correctly named certificate
  _info "Step 5: Verifying service certificate assignments..."
  local verification_failed=0
  
  if [ "$MIKROTIK_UPDATE_WWW_SSL" = "true" ]; then
    if ! verify_service_certificate "www-ssl" "$final_cert_name"; then
      verification_failed=$((verification_failed + 1))
    fi
  fi
  
  if [ "$MIKROTIK_UPDATE_API_SSL" = "true" ]; then
    if ! verify_service_certificate "api-ssl" "$final_cert_name"; then
      verification_failed=$((verification_failed + 1))
    fi
  fi
  
  # Step 6: Show final certificate status
  _info "Step 6: Verifying final certificate deployment..."
  local final_response
  if final_response=$(api_call "GET" "/certificate?common-name=$domain" ""); then
    if [ -n "$final_response" ] && [ "$final_response" != "[]" ]; then
      local final_cert_name_actual=$(echo "$final_response" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
      local final_cert_expiry=$(echo "$final_response" | grep -o '"invalid-after":"[^"]*"' | cut -d'"' -f4)
      local final_cert_expires_after=$(echo "$final_response" | grep -o '"expires-after":"[^"]*"' | cut -d'"' -f4)
      local final_cert_id=$(echo "$final_response" | grep -o '"\.id":"[^"]*"' | cut -d'"' -f4)
      
      # Determine if certificate is valid or expired
      local final_status="Valid"
      if echo "$final_cert_expires_after" | grep -q "^-"; then
        final_status="EXPIRED"
      fi
      
      _info "New certificate deployed: $final_cert_name_actual ($final_status, expires: $final_cert_expiry)"
      _debug "Final certificate details: ID=$final_cert_id, Name=$final_cert_name_actual, Status=$final_status, Expires=$final_cert_expiry"
    fi
  fi
  
  # Report results
  if [ "$services_failed" -gt 0 ]; then
    _warn "Certificate uploaded successfully, but $services_failed service(s) failed to update"
    if [ "$services_updated" -gt 0 ]; then
      _info "$services_updated service(s) updated successfully"
    fi
    return 1
  elif [ "$verification_failed" -gt 0 ]; then
    _warn "Certificate deployed and services updated, but $verification_failed service(s) verification failed"
    _info "Services are using working certificates, but names may not match expected format"
    return 0
  else
    _info "Certificate deployment completed successfully!"
    if [ "$services_updated" -gt 0 ]; then
      _info "$services_updated service(s) updated with certificate: $final_cert_name"
    fi
    return 0
  fi
}

# ACME.sh deploy hook function - this is what ACME.sh calls
mikrotik_deploy_hook() {
  # Debug: Always log what we received
  echo "[DEBUG] Deploy hook called with $# parameters:" >&2
  echo "[DEBUG] \$1 = $1" >&2
  echo "[DEBUG] \$2 = $2" >&2
  echo "[DEBUG] \$3 = $3" >&2
  echo "[DEBUG] \$4 = $4" >&2
  echo "[DEBUG] \$5 = $5" >&2
  echo "[DEBUG] Working directory: $(pwd)" >&2
  
  # Check if running as ACME.sh deploy hook
  if [ $# -eq 5 ]; then
    echo "[DEBUG] Proceeding with deployment..." >&2
    mikrotik_deploy "$1" "$2" "$3" "$4" "$5"
  else
    echo "[DEBUG] Wrong number of parameters ($#)" >&2
    return 1
  fi
}

# Main entry point for standalone execution
main() {
  # Debug: Always log what we received
  echo "[DEBUG] Script called with $# parameters:" >&2
  echo "[DEBUG] \$0 = $0" >&2
  echo "[DEBUG] \$1 = $1" >&2
  echo "[DEBUG] \$2 = $2" >&2
  echo "[DEBUG] \$3 = $3" >&2
  echo "[DEBUG] \$4 = $4" >&2
  echo "[DEBUG] \$5 = $5" >&2
  echo "[DEBUG] Working directory: $(pwd)" >&2
  echo "[DEBUG] Script location: $(dirname "$0")" >&2
  
  # Check if running as ACME.sh deploy hook
  if [ $# -eq 5 ]; then
    echo "[DEBUG] Proceeding with deployment..." >&2
    mikrotik_deploy "$1" "$2" "$3" "$4" "$5"
  else
    echo "[DEBUG] Wrong number of parameters ($#), showing usage" >&2
    echo "MikroTik RouterOS API Deploy Hook for ACME.sh"
    echo "Usage: $0 <domain> <key_file> <cert_file> <ca_file> <fullchain_file>"
    echo ""
    echo "This script is designed to be used as an ACME.sh deploy hook:"
    echo "  acme.sh --deploy -d example.com --deploy-hook mikrotik"
    echo ""
    echo "Configuration:"
    echo "  Copy examples/mikrotik.env.example to mikrotik.env and customize"
    echo "  Or set environment variables: MIKROTIK_HOST, MIKROTIK_USERNAME, MIKROTIK_PASSWORD"
    exit 1
  fi
}

# Run main function with all arguments if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ] || [ -z "${BASH_SOURCE[0]}" ]; then
  main "$@"
fi