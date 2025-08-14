class Swiftcapture < Formula
  desc "Professional screen recording tool for macOS with comprehensive CLI interface"
  homepage "https://github.com/GlennWong/SwiftCapture"
  url "https://github.com/GlennWong/SwiftCapture/archive/v2.1.0.tar.gz"
  sha256 "61a8bb6b53affe43da3a00c765529262bc5d5d84525046cfd4848ee28c68eca6"
  license "MIT"
  head "https://github.com/GlennWong/SwiftCapture.git", branch: "main"

  depends_on xcode: ["14.3", :build]
  depends_on :macos => :monterey # macOS 12.0+

  def install
    system "swift", "build", "--disable-sandbox", "-c", "release"
    bin.install ".build/release/SwiftCapture" => "scap"
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
      
      Usage examples:
        scap --help                    # Show comprehensive help
        scap --duration 30000          # Record for 30 seconds
        scap --screen-list             # List available screens
        scap --app-list                # List running applications
        scap --enable-microphone       # Include microphone audio
    EOS
  end

  test do
    # Test that the binary was installed correctly
    assert_match "SwiftCapture", shell_output("#{bin}/scap --version")
    
    # Test help command
    assert_match "Professional screen recording tool", shell_output("#{bin}/scap --help")
    
    # Test screen list command (should not fail even without permissions)
    system "#{bin}/scap", "--screen-list"
  end
end