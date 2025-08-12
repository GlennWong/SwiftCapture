class Swiftcapture < Formula
  desc "Professional screen recording tool for macOS with comprehensive CLI interface"
  homepage "https://github.com/your-username/SwiftCapture"
  url "https://github.com/your-username/SwiftCapture/archive/v2.0.0.tar.gz"
  sha256 "YOUR_SHA256_HASH_HERE"
  license "MIT"
  head "https://github.com/your-username/SwiftCapture.git", branch: "main"

  # System requirements
  depends_on xcode: ["14.3", :build]
  depends_on :macos => :monterey # macOS 12.0+, but we need 12.3+ for ScreenCaptureKit

  # Swift ArgumentParser is included as a dependency in Package.swift
  # No additional Homebrew dependencies needed

  def install
    # Build the release version
    system "swift", "build", "--disable-sandbox", "-c", "release", "--arch", "arm64", "--arch", "x86_64"
    
    # Install the binary
    bin.install ".build/release/SwiftCapture" => "scap"
    
    # Install man page if it exists
    if File.exist?("docs/scap.1")
      man1.install "docs/scap.1"
    end
    
    # Install shell completions if they exist
    if File.exist?("completions/scap.bash")
      bash_completion.install "completions/scap.bash" => "scap"
    end
    
    if File.exist?("completions/scap.zsh")
      zsh_completion.install "completions/scap.zsh" => "_scap"
    end
    
    if File.exist?("completions/scap.fish")
      fish_completion.install "completions/scap.fish"
    end
  end

  def post_install
    # Create preset directory
    (var/"scap").mkpath
  end

  def caveats
    <<~EOS
      SwiftCapture requires Screen Recording permission to function properly.
      
      To grant permission:
      1. Open System Preferences > Security & Privacy > Privacy
      2. Select "Screen Recording" from the left sidebar  
      3. Click the lock icon and enter your password
      4. Add your terminal application (Terminal, iTerm2, etc.)
      5. Enable the checkbox next to your terminal
      6. Restart your terminal application
      
      For microphone recording (optional), also grant Microphone permission
      following the same steps in the "Microphone" section.
      
      Quick start:
        scap --help                    # Show comprehensive help
        scap --duration 30000          # Record for 30 seconds  
        scap --screen-list             # List available screens
        scap --app-list                # List running applications
        scap --enable-microphone       # Include microphone audio
        
      Presets are stored in: #{var}/scap/
    EOS
  end

  test do
    # Test that the binary was installed correctly and shows version
    assert_match "SwiftCapture", shell_output("#{bin}/scap --version 2>&1")
    
    # Test help command
    help_output = shell_output("#{bin}/scap --help 2>&1")
    assert_match "Professional screen recording tool", help_output
    assert_match "duration", help_output
    assert_match "output", help_output
    
    # Test that screen list command doesn't crash (may fail due to permissions)
    # We just check it doesn't segfault or have major issues
    system "#{bin}/scap", "--screen-list"
    
    # Test that app list command doesn't crash
    system "#{bin}/scap", "--app-list"
    
    # Test preset list (should work without permissions)
    system "#{bin}/scap", "--list-presets"
  end
end