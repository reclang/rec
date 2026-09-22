class Reclang < Formula
  desc "Recreational Programming Language compiler"
  homepage "https://github.com/reclang/rec"
  url "https://github.com/reclang/rec/releases/download/v0.0.6/reclang-0.0.6.tar.gz"
  sha256 "e5b8acea45f72984835b6e5508e7538658d9e256ade58843ad70d612540d2b30"
  license "Apache-2.0" => { with: "LLVM-exception" }

  depends_on "ldc" => :build

  def install
    # the D runtime is linked in, so ldc is a build dependency only
    system "make", "install", "PREFIX=#{prefix}",
           "DFLAGS=-O -release -link-defaultlib-shared=false"
  end

  test do
    assert_equal version.to_s, shell_output("#{bin}/reclang --version").chomp
    (testpath/"hello.rec").write <<~EOS
      void main() {
        writeln("Hello, world!")
        exit(42)
      }
    EOS
    system bin/"reclang", "-o", "hello", "hello.rec"
    assert_equal "Hello, world!\n", shell_output("#{testpath}/hello", 42)
  end
end
