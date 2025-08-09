class Screenrecorder < Formula
  desc "Professional screen recording tool for macOS with comprehensive CLI interface"
  homepage "https://github.com/your-username/ScreenRecorder"
  url "https://github.com/your-username/ScreenRecorder/archive/v2.0.0.tar.gz"
  sha256 "YOUR_SHA256_HASH_HERE"
  license "MIT"
  head "https://github.com/your-username/ScreenRecorder.git", branch: "main"

  # System requirements
  depends_on xcode: ["14.3", :build]
  depends_on :macos => :monterey # macOS 12.0+, but we need 12.3+ for ScreenCaptureKit

  # Swift ArgumentParser is included as a dependency in Package.swift
  # No additional Homebrew dependencies needed

  def install
    # Build the release version
    system "swift", "build", "--disable-sandbox", "-c", "release", "--arch", "arm64", "--arch", "x86_64"
    
    # Install the binary
    bin.install ".build/release/ScreenRecorder" => "screenrecorder"
    
    # Install man page if it exists
    if File.exist?("docs/screenrecorder.1")
      man1.install "docs/screenrecorder.1"
    end
    
    # Install shell completions if they exist
    if File.exist?("completions/screenrecorder.bash")
      bash_completion.install "completions/screenrecorder.bash" => "screenrecorder"
    end
    
    if File.exist?("completions/screenrecorder.zsh")
      zsh_completion.install "completions/screenrecorder.zsh" => "_screenrecorder"
    end
    
    if File.exist?("completions/screenrecorder.fish")
      fish_completion.install "completions/screenrecorder.fish"
    end
  end

  def post_install
    # Create preset directory
    (var/"screenrecorder").mkpath
  end

  def caveats
    <<~EOS
      ScreenRecorder requires Screen Recording permission to function properly.
      
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
        screenrecorder --help                    # Show comprehensive help
        screenrecorder --duration 30000          # Record for 30 seconds  
        screenrecorder --screen-list             # List available screens
        screenrecorder --app-list                # List running applications
        screenrecorder --enable-microphone       # Include microphone audio
        
      Presets are stored in: #{var}/screenrecorder/
    EOS
  end

  test do
    # Test that the binary was installed correctly and shows version
    assert_match "ScreenRecorder", shell_output("#{bin}/screenrecorder --version 2>&1")
    
    # Test help command
    help_output = shell_output("#{bin}/screenrecorder --help 2>&1")
    assert_match "Professional screen recording tool", help_output
    assert_match "duration", help_output
    assert_match "output", help_output
    
    # Test that screen list command doesn't crash (may fail due to permissions)
    # We just check it doesn't segfault or have major issues
    system "#{bin}/screenrecorder", "--screen-list"
    
    # Test that app list command doesn't crash
    system "#{bin}/screenrecorder", "--app-list"
    
    # Test preset list (should work without permissions)
    system "#{bin}/screenrecorder", "--list-presets"
  end
end