class Perl < Formula
  desc "Highly capable, feature-rich programming language"
  homepage "https://www.perl.org/"
  url "https://www.cpan.org/src/5.0/perl-5.26.1.tar.xz"
  sha256 "fe8208133e73e47afc3251c08d2c21c5a60160165a8ab8b669c43a420e4ec680"
  head "https://perl5.git.perl.org/perl.git", :branch => "blead"

  bottle do
    sha256 "22c36fb65fbcdc51ed56a18d9168d3c513bee2855b0b92772992c32b86bea36c" => :high_sierra
    sha256 "022fe33d21f7a831c4f6f599a68894a6b4c248169d5a4eb6683ca73efe143eb3" => :sierra
    sha256 "d9f66743cfc05baaf4d51f5cc30f74048a45d33ac195f3a70d5448cc76a362c1" => :el_capitan
    sha256 "e71c9ab3ab09749d88434f13b8fd4b3dac7a4121111c2f9183c9d9ce9afab566" => :x86_64_linux
  end

  option "with-dtrace", "Build with DTrace probes"
  option "without-test", "Skip running the build test suite"

  unless OS.mac?
    depends_on "gdbm"
    depends_on "berkeley-db"

    # required for XML::Parser
    depends_on "expat"
  end

  def install
    if MacOS.version == :el_capitan && MacOS::Xcode.installed? && MacOS::Xcode.version >= "8.0"
      %w[cpan/IPC-Cmd/lib/IPC/Cmd.pm dist/Time-HiRes/Changes
         dist/Time-HiRes/HiRes.pm dist/Time-HiRes/HiRes.xs
         dist/Time-HiRes/Makefile.PL dist/Time-HiRes/fallback/const-c.inc
         dist/Time-HiRes/t/clock.t pod/perl588delta.pod
         pod/perlperf.pod].each do |f|
        inreplace f do |s|
          s.gsub! "clock_gettime", "perl_clock_gettime"
          s.gsub! "clock_getres", "perl_clock_getres", false
        end
      end
    end

    args = %W[
      -des
      -Dprefix=#{prefix}
      -Dprivlib=#{lib}/perl5/#{version}
      -Dsitelib=#{lib}/perl5/site_perl/#{version}
      -Dotherlibdirs=#{HOMEBREW_PREFIX}/lib/perl5/site_perl/#{version}
      -Dperlpath=#{opt_bin}/perl
      -Dstartperl=#!#{opt_bin}/perl
      -Dman1dir=#{man1}
      -Dman3dir=#{man3}
      -Duseshrplib
      -Duselargefiles
      -Dusethreads
    ]

    args << "-Dusedtrace" if build.with? "dtrace"
    args << "-Dusedevel" if build.head?
    # Fix for https://github.com/Linuxbrew/homebrew-core/issues/405
    args << "-Dlocincpth=#{HOMEBREW_PREFIX}/include" if OS.linux?

    system "./Configure", *args
    system "make"

    # OS X El Capitan's SIP feature prevents DYLD_LIBRARY_PATH from being
    # passed to child processes, which causes the make test step to fail.
    # https://rt.perl.org/Ticket/Display.html?id=126706
    # https://github.com/Homebrew/legacy-homebrew/issues/41716
    # On Linux (in travis / docker container), the op/getppid.t fails too, disable the tests:
    # https://rt.perl.org/Public/Bug/Display.html?id=130143
    if OS.mac? && MacOS.version < :el_capitan
      system "make", "test" if build.with? "test"
    end

    system "make", "install"

    # expose libperl.so to ensure we aren't using a brewed executable
    # but a system library
    if OS.linux?
      perl_core = Pathname.new(`#{bin/"perl"} -MConfig -e 'print $Config{archlib}'`)+"CORE"
      lib.install_symlink perl_core/"libperl.so"
    end
  end

  def caveats; <<~EOS
    By default non-brewed cpan modules are installed to the Cellar. If you wish
    for your modules to persist across updates we recommend using `local::lib`.

    You can set that up like this:
      PERL_MM_OPT="INSTALL_BASE=$HOME/perl5" cpan local::lib
      echo 'eval "$(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)"' >> #{shell_profile}
    EOS
  end

  def post_install
    # CPAN modules installed via the system package manager will not be visible to
    # brewed Perl. As a temporary measure, install critical CPAN modules to ensure
    # they are available. See https://github.com/Linuxbrew/homebrew-core/pull/1064
    unless OS.mac?
      ENV.with_build_environment do
        ENV["PERL_MM_USE_DEFAULT"] = "1"
        system bin/"cpan", "-i", "XML::Parser"
        system bin/"cpan", "-i", "XML::SAX"
      end
    end
  end

  test do
    (testpath/"test.pl").write "print 'Perl is not an acronym, but JAPH is a Perl acronym!';"
    system "#{bin}/perl", "test.pl"
  end
end
