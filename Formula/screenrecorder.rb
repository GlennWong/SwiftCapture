class Screenrecorder < Formula
  desc "Professional screen recording tool for macOS with comprehensive CLI interface"
  homepage "https://github.com/your-username/ScreenRecorder"
  url "https://github.com/your-username/ScreenRecorder/archive/v2.0.0.tar.gz"
  sha256 "YOUR_SHA256_HASH_HERE"
  license "MIT"
  head "https://github.com/your-username/ScreenRecorder.git", branch: "main"

  depends_on xcode: ["14.3", :build]
  depends_on :macos => :monterey # macOS 12.0+

  def install
    system "swift", "build", "--disable-sandbox", "-c", "release"
    bin.install ".build/release/ScreenRecorder" => "screenrecorder"
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
      
      Usage examples:
        screenrecorder --help                    # Show comprehensive help
        screenrecorder --duration 30000          # Record for 30 seconds
        screenrecorder --screen-list             # List available screens
        screenrecorder --app-list                # List running applications
        screenrecorder --enable-microphone       # Include microphone audio
    EOS
  end

  test do
    # Test that the binary was installed correctly
    assert_match "ScreenRecorder", shell_output("#{bin}/screenrecorder --version")
    
    # Test help command
    assert_match "Professional screen recording tool", shell_output("#{bin}/screenrecorder --help")
    
    # Test screen list command (should not fail even without permissions)
    system "#{bin}/screenrecorder", "--screen-list"
  end
end