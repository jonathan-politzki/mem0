#!/bin/bash

# OpenMemory Development Environment Setup Script
# One-command setup for local development with minimal user input

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_LOCAL_FILE="$PROJECT_ROOT/.env.local"
ENV_LOCAL_TEMPLATE="$PROJECT_ROOT/env.local.example"
API_ENV_FILE="$PROJECT_ROOT/api/.env"
API_ENV_TEMPLATE="$PROJECT_ROOT/env.example"
UI_ENV_FILE="$PROJECT_ROOT/ui/.env.local"

# Helper functions
print_header() {
    echo -e "\n${BLUE}$1${NC}"
    echo "=================================="
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to create environment files with API keys
create_env_files_with_keys() {
    local openai_key="$1"
    local gemini_key="$2"
    
    print_info "Creating environment files with your API keys..."
    
    # Create main .env.local file
    cat > "$ENV_LOCAL_FILE" << EOF
# OpenMemory Local Development Environment
# This file is automatically configured by the setup script
# 
# IMPORTANT: This file should NOT be committed to Git

# =============================================================================
# REQUIRED API KEYS (Configured by Setup)
# =============================================================================
# OpenAI Configuration (REQUIRED - Get from: https://platform.openai.com/api-keys)
OPENAI_API_KEY=$openai_key
LLM_PROVIDER=openai
OPENAI_MODEL=gpt-4o-mini
EMBEDDER_PROVIDER=openai
EMBEDDER_MODEL=text-embedding-3-small

# Gemini (OPTIONAL - Get from: https://makersuite.google.com/app/apikey)
GEMINI_API_KEY=$gemini_key

# =============================================================================
# AUTO-GENERATED CONFIGURATION (DO NOT EDIT MANUALLY)
# =============================================================================
# These values are automatically set by the setup script

# Supabase Local Configuration (Will be auto-generated by 'npx supabase start')
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU

# Database Configuration (Auto-configured for local development)
DATABASE_URL=postgresql://postgres:postgres@localhost:54322/postgres

# Vector Database Configuration (Auto-configured for Docker)
QDRANT_HOST=localhost
QDRANT_PORT=6333
QDRANT_API_KEY=
MAIN_QDRANT_COLLECTION_NAME=openmemory_dev

# Development Settings
DEBUG=true
LOG_LEVEL=INFO
PYTHONUNBUFFERED=1
NEXT_TELEMETRY_DISABLED=1
NODE_ENV=development
EOF

    # Create API .env file
    cat > "$API_ENV_FILE" << EOF
# OpenMemory API Environment Configuration
# Auto-generated by setup script

# =============================================================================
# API KEYS (User Provided)
# =============================================================================
OPENAI_API_KEY=$openai_key
LLM_PROVIDER=openai
OPENAI_MODEL=gpt-4o-mini
EMBEDDER_PROVIDER=openai
EMBEDDER_MODEL=text-embedding-3-small

GEMINI_API_KEY=$gemini_key

# =============================================================================
# SUPABASE CONFIGURATION (Auto-configured)
# =============================================================================
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU

# =============================================================================
# DATABASE CONFIGURATION
# =============================================================================
DATABASE_URL=postgresql://postgres:postgres@localhost:54322/postgres

# =============================================================================
# VECTOR DATABASE CONFIGURATION
# =============================================================================
QDRANT_HOST=localhost
QDRANT_PORT=6333
QDRANT_API_KEY=
MAIN_QDRANT_COLLECTION_NAME=openmemory_dev

# =============================================================================
# DEVELOPMENT SETTINGS
# =============================================================================
DEBUG=true
LOG_LEVEL=INFO
PYTHONUNBUFFERED=1
ENVIRONMENT=local
EOF

    # Create UI .env.local file with API keys for frontend
    cat > "$UI_ENV_FILE" << EOF
# UI Local Development Environment
# Auto-generated by setup script

# =============================================================================
# API KEYS FOR FRONTEND (User Provided)
# =============================================================================
# OpenAI API Key (for frontend API routes)
OPENAI_API_KEY=$openai_key
NEXT_PUBLIC_OPENAI_API_KEY=$openai_key

# Gemini API Key (for frontend API routes)
GEMINI_API_KEY=$gemini_key
NEXT_PUBLIC_GEMINI_API_KEY=$gemini_key

# =============================================================================
# API CONNECTION
# =============================================================================
# Points to local API backend
NEXT_PUBLIC_API_URL=http://localhost:8765

# =============================================================================
# SUPABASE CONFIGURATION (Auto-configured)
# =============================================================================
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0

# =============================================================================
# DEVELOPMENT SETTINGS
# =============================================================================
NEXT_TELEMETRY_DISABLED=1
NODE_ENV=development
EOF

    print_success "Environment files created with your API keys"
}

# Main setup function
main() {
    print_header "🚀 OpenMemory Complete Setup"
    
    echo "This script will set up your complete development environment."
    echo "After setup, both backend AND frontend will work together seamlessly!"
    echo ""
    
    # Check prerequisites
    print_header "📋 Checking Prerequisites"
    
    local missing_deps=()
    
    if ! check_command "node"; then
        missing_deps+=("Node.js (https://nodejs.org/)")
    else
        print_success "Node.js found: $(node --version)"
    fi
    
    if ! check_command "npm"; then
        missing_deps+=("npm (comes with Node.js)")
    else
        print_success "npm found: $(npm --version)"
    fi
    
    if ! check_command "python3" && ! check_command "python"; then
        missing_deps+=("Python 3.8+ (https://python.org/)")
    else
        local python_cmd="python3"
        if ! check_command "python3"; then
            python_cmd="python"
        fi
        print_success "Python found: $($python_cmd --version)"
    fi
    
    if ! check_command "docker"; then
        missing_deps+=("Docker Desktop (https://docker.com/products/docker-desktop)")
    else
        print_success "Docker found: $(docker --version)"
        
        # Check if Docker is running
        if ! docker info >/dev/null 2>&1; then
            print_error "Docker is installed but not running. Please start Docker Desktop."
            exit 1
        fi
        print_success "Docker is running"
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required dependencies:"
        printf '%s\n' "${missing_deps[@]}"
        echo ""
        echo "Please install the missing dependencies and run this script again."
        exit 1
    fi
    
    # Change to project directory
    cd "$PROJECT_ROOT"
    
    # API Key Configuration - Create files first, then let user edit
    print_header "🔑 API Key Configuration"
    
    echo "To have a fully functional development setup, you need API keys."
    echo "The application will work for authentication and basic features without them,"
    echo "but AI features require these keys."
    echo ""
    echo "I'll create the environment files with placeholders for you to edit."
    echo ""
    
    # Create environment files with placeholders
    create_env_files_with_keys "your_openai_api_key_here" ""
    
    echo "📝 Environment files created with placeholders:"
    echo "   • openmemory/.env.local"
    echo "   • openmemory/api/.env" 
    echo "   • openmemory/ui/.env.local"
    echo ""
    echo "🔑 Please add your API keys to these files:"
    echo ""
    echo "   📍 Required: OPENAI_API_KEY"
    echo "      Get from: https://platform.openai.com/api-keys"
    echo "      Replace 'your_openai_api_key_here' with your actual key"
    echo ""
    echo "   📍 Optional: GEMINI_API_KEY" 
    echo "      Get from: https://makersuite.google.com/app/apikey"
    echo "      Leave empty if you don't have one"
    echo ""
    echo "💡 Tip: You can edit all files, but the main one is: openmemory/.env.local"
    echo "   The setup script will sync your keys to the other files automatically."
    echo ""
    
    # Wait for user to edit the files
    echo "Press Enter when you've added your API keys to continue setup..."
    read -r
    
    # Install dependencies
    print_header "📦 Installing Dependencies"
    
    if [ ! -f "package.json" ]; then
        print_error "package.json not found. Are you in the correct directory?"
        exit 1
    fi
    
    npm install --silent
    print_success "Supabase CLI installed"
    
    # Install Python dependencies
    if [ -d "api" ] && [ -f "api/requirements.txt" ]; then
        print_info "Installing Python dependencies..."
        cd api && pip install -r requirements.txt --quiet && cd ..
        print_success "Python dependencies installed"
    fi
    
    # Install UI dependencies
    if [ -d "ui" ] && [ -f "ui/package.json" ]; then
        print_info "Installing UI dependencies..."
        cd ui && npm install --silent && cd ..
        print_success "UI dependencies installed"
    fi
    
    # Start Supabase
    print_header "🗄️ Starting Local Supabase"
    
    echo "Initializing Supabase project (if needed)..."
    if [ ! -f "$PROJECT_ROOT/supabase/config.toml" ]; then
        print_info "Initializing new Supabase project..."
        npx supabase init
    fi
    
    echo "Starting local Supabase services (this may take a moment)..."
    npx supabase start
    
    print_success "Supabase started successfully!"
    
    # Auto-extract and configure Supabase keys using dedicated script
    print_header "🔧 Finalizing Environment Configuration"
    
    echo "Updating environment files with current Supabase keys..."
    chmod +x "$PROJECT_ROOT/scripts/configure-env.sh"
    
    if "$PROJECT_ROOT/scripts/configure-env.sh"; then
        print_success "Environment automatically updated with current Supabase keys!"
    else
        print_error "Failed to configure environment automatically."
        print_info "You may need to run 'make configure-env' manually later."
    fi
    
    # Start Qdrant vector database
    print_header "🔍 Starting Vector Database"
    
    echo "Starting Qdrant vector database..."
    if docker-compose up -d qdrant_db >/dev/null 2>&1; then
        print_success "Qdrant started successfully!"
    else
        print_warning "Could not start Qdrant automatically. You may need to run 'docker-compose up -d qdrant_db' manually."
    fi
    
    # Final validation
    print_header "✅ Validating Setup"
    
    echo "Running environment validation..."
    chmod +x "$PROJECT_ROOT/scripts/validate-env.sh"
    
    if "$PROJECT_ROOT/scripts/validate-env.sh"; then
        print_success "Environment validation passed!"
    else
        print_warning "Some validation checks failed, but setup may still work."
    fi
    
    # Success message
    print_header "🎉 Setup Complete!"
    
    echo "Your OpenMemory development environment is ready!"
    echo ""
    echo "📍 What's been set up:"
    echo "   ✅ All dependencies installed"
    echo "   ✅ Environment files created with your API keys"
    echo "   ✅ Supabase local database running"
    echo "   ✅ Qdrant vector database running"
    echo "   ✅ Frontend and backend configured to work together"
    echo ""
    echo "🚀 Next steps:"
    echo "   1. Run 'make dev' to start both frontend and backend"
    echo "   2. Visit http://localhost:3000 for the UI"
    echo "   3. Visit http://localhost:8765/docs for the API docs"
    echo "   4. Visit http://localhost:54323 for Supabase Studio"
    echo ""
    echo "🔧 Useful commands:"
    echo "   make dev      - Start complete development environment"
    echo "   make status   - Check what's running"
    echo "   make stop     - Stop all services"
    echo "   make help     - See all available commands"
    echo ""
    
    # Check if user added real API keys
    if [ -f "$ENV_LOCAL_FILE" ]; then
        CURRENT_OPENAI_KEY=$(grep '^OPENAI_API_KEY=' "$ENV_LOCAL_FILE" | cut -d'=' -f2- | head -1)
        if [ "$CURRENT_OPENAI_KEY" = "your_openai_api_key_here" ]; then
            print_warning "Remember: You still have placeholder API keys!"
            echo "   AI features will be disabled until you add real API keys."
            echo "   Edit the environment files and replace 'your_openai_api_key_here' with your actual key."
        else
            echo "🤖 Your AI features are ready to go with your provided API keys!"
        fi
    else
        echo "🤖 Your AI features are ready to go with your provided API keys!"
    fi
    
    echo ""
    echo "Happy coding! 🚀"
}

# Run main function
main "$@" 