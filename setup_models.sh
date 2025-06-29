#!/bin/bash

# setup_models.sh - Download CoreML models for Veda Voice Assistant
# This script downloads the large CoreML models from Hugging Face and places them in the correct locations

set -e  # Exit on any error

echo "🚀 Setting up Veda Voice Assistant models..."
echo "📍 Repository: TVRRaviteja/Gemma2-CoreML"
echo ""

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: Python 3 is required but not installed."
    echo "Please install Python 3 and try again."
    exit 1
fi

# Check if huggingface_hub is installed, install if not
echo "📦 Checking Hugging Face Hub installation..."
python3 -c "import huggingface_hub" 2>/dev/null || {
    echo "📦 Installing Hugging Face Hub..."
    pip3 install -U huggingface_hub
}

# Create necessary directories if they don't exist
echo "📁 Creating model directories..."
mkdir -p "VoiceFoundationApp/VoiceFoundationApp"
mkdir -p "models"

# Download models using Python script
echo "⬇️  Downloading models from Hugging Face (this may take a while)..."
echo "💡 Note: The models are large files (~6.5GB total), please be patient..."
echo ""

python3 << 'EOF'
import os
import sys
from huggingface_hub import hf_hub_download, login
import shutil

def download_and_setup_models():
    try:
        print("🔑 Note: Using cached authentication token")
        print("📂 Downloading Gemma-2B-IT-Stateful-128.mlpackage...")
        
        # Download the 128 model files
        model_file_128 = hf_hub_download(
            repo_id="TVRRaviteja/Gemma2-CoreML",
            filename="Gemma-2B-IT-Stateful-128.mlpackage/Data/com.apple.CoreML/model.mlmodel",
            cache_dir="./temp_download"
        )
        
        weight_file_128 = hf_hub_download(
            repo_id="TVRRaviteja/Gemma2-CoreML", 
            filename="Gemma-2B-IT-Stateful-128.mlpackage/Data/com.apple.CoreML/weights/weight.bin",
            cache_dir="./temp_download"
        )
        
        manifest_file_128 = hf_hub_download(
            repo_id="TVRRaviteja/Gemma2-CoreML",
            filename="Gemma-2B-IT-Stateful-128.mlpackage/Manifest.json",
            cache_dir="./temp_download"
        )
        
        print("📂 Downloading Gemma-2B-IT-Stateful-4bit-128.mlpackage...")
        
        # Download the 4bit model files
        model_file_4bit = hf_hub_download(
            repo_id="TVRRaviteja/Gemma2-CoreML",
            filename="Gemma-2B-IT-Stateful-4bit-128.mlpackage/Data/com.apple.CoreML/model.mlmodel",
            cache_dir="./temp_download"
        )
        
        weight_file_4bit = hf_hub_download(
            repo_id="TVRRaviteja/Gemma2-CoreML",
            filename="Gemma-2B-IT-Stateful-4bit-128.mlpackage/Data/com.apple.CoreML/weights/weight.bin", 
            cache_dir="./temp_download"
        )
        
        manifest_file_4bit = hf_hub_download(
            repo_id="TVRRaviteja/Gemma2-CoreML",
            filename="Gemma-2B-IT-Stateful-4bit-128.mlpackage/Manifest.json",
            cache_dir="./temp_download"
        )
        
        print("📋 Setting up model directory structure...")
        
        # Create directory structure for 128 model
        os.makedirs("Gemma-2B-IT-Stateful-128.mlpackage/Data/com.apple.CoreML/weights", exist_ok=True)
        os.makedirs("VoiceFoundationApp/VoiceFoundationApp/Gemma-2B-IT-Stateful-128.mlpackage/Data/com.apple.CoreML/weights", exist_ok=True)
        
        # Create directory structure for 4bit model  
        os.makedirs("Gemma-2B-IT-Stateful-4bit-128.mlpackage/Data/com.apple.CoreML/weights", exist_ok=True)
        os.makedirs("VoiceFoundationApp/VoiceFoundationApp/Gemma-2B-IT-Stateful-4bit-128.mlpackage/Data/com.apple.CoreML/weights", exist_ok=True)
        
        # Copy 128 model files to project root
        shutil.copy2(model_file_128, "Gemma-2B-IT-Stateful-128.mlpackage/Data/com.apple.CoreML/model.mlmodel")
        shutil.copy2(weight_file_128, "Gemma-2B-IT-Stateful-128.mlpackage/Data/com.apple.CoreML/weights/weight.bin")
        shutil.copy2(manifest_file_128, "Gemma-2B-IT-Stateful-128.mlpackage/Manifest.json")
        
        # Copy 128 model files to app directory
        shutil.copy2(model_file_128, "VoiceFoundationApp/VoiceFoundationApp/Gemma-2B-IT-Stateful-128.mlpackage/Data/com.apple.CoreML/model.mlmodel")
        shutil.copy2(weight_file_128, "VoiceFoundationApp/VoiceFoundationApp/Gemma-2B-IT-Stateful-128.mlpackage/Data/com.apple.CoreML/weights/weight.bin")
        shutil.copy2(manifest_file_128, "VoiceFoundationApp/VoiceFoundationApp/Gemma-2B-IT-Stateful-128.mlpackage/Manifest.json")
        
        # Copy 4bit model files to project root
        shutil.copy2(model_file_4bit, "Gemma-2B-IT-Stateful-4bit-128.mlpackage/Data/com.apple.CoreML/model.mlmodel")
        shutil.copy2(weight_file_4bit, "Gemma-2B-IT-Stateful-4bit-128.mlpackage/Data/com.apple.CoreML/weights/weight.bin")
        shutil.copy2(manifest_file_4bit, "Gemma-2B-IT-Stateful-4bit-128.mlpackage/Manifest.json")
        
        # Copy 4bit model files to app directory
        shutil.copy2(model_file_4bit, "VoiceFoundationApp/VoiceFoundationApp/Gemma-2B-IT-Stateful-4bit-128.mlpackage/Data/com.apple.CoreML/model.mlmodel")
        shutil.copy2(weight_file_4bit, "VoiceFoundationApp/VoiceFoundationApp/Gemma-2B-IT-Stateful-4bit-128.mlpackage/Data/com.apple.CoreML/weights/weight.bin")
        shutil.copy2(manifest_file_4bit, "VoiceFoundationApp/VoiceFoundationApp/Gemma-2B-IT-Stateful-4bit-128.mlpackage/Manifest.json")
        
        print("✅ Successfully set up Gemma-2B-IT-Stateful-128.mlpackage")
        print("✅ Successfully set up Gemma-2B-IT-Stateful-4bit-128.mlpackage")
        
        # Clean up temp directory
        if os.path.exists("./temp_download"):
            shutil.rmtree("./temp_download")
            print("🧹 Cleaned up temporary files")
            
        return True
        
    except Exception as e:
        print(f"❌ Error downloading models: {e}")
        print("💡 Make sure you have access to the private repository TVRRaviteja/Gemma2-CoreML")
        print("💡 You may need to run: huggingface-cli login")
        return False

if __name__ == "__main__":
    success = download_and_setup_models()
    if not success:
        sys.exit(1)
EOF

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 Model setup complete!"
    echo ""
    echo "📋 Summary:"
    echo "  ✅ Gemma-2B-IT-Stateful-128.mlpackage (~5GB)"
    echo "  ✅ Gemma-2B-IT-Stateful-4bit-128.mlpackage (~1.4GB)"
    echo ""
    echo "📂 Models have been placed in:"
    echo "  • Project root directory (for reference)"
    echo "  • VoiceFoundationApp/VoiceFoundationApp/ (for Xcode builds)"
    echo ""
    echo "🚀 You can now open the project in Xcode and build the Veda Voice Assistant!"
    echo ""
    echo "💡 Next steps:"
    echo "  1. Open VoiceFoundationApp/VoiceFoundationApp.xcodeproj in Xcode"
    echo "  2. Select your target device"
    echo "  3. Build and run the app"
else
    echo ""
    echo "❌ Model setup failed!"
    echo ""
    echo "🔧 Troubleshooting:"
    echo "  1. Make sure you have internet connection"
    echo "  2. Verify you have access to the private repository"
    echo "  3. Try running: huggingface-cli login"
    echo "  4. Re-run this script: ./setup_models.sh"
    exit 1
fi 