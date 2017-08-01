class SuiteSparse < Formula
  desc "Suite of Sparse Matrix Software"
  homepage "http://faculty.cse.tamu.edu/davis/suitesparse.html"
  url "http://faculty.cse.tamu.edu/davis/SuiteSparse/SuiteSparse-4.5.5.tar.gz"
  sha256 "b9a98de0ddafe7659adffad8a58ca3911c1afa8b509355e7aa58b02feb35d9b6"

  bottle do
    cellar :any
    sha256 "9344c95830eebd2e6a418beb5a3671cb3955a8b798486994d2c2163c7a4a86c2" => :sierra
    sha256 "925358aebf66ab22eb8f577cb3adcfc1f16045645266c4bab226a520261f78c0" => :el_capitan
    sha256 "3a527e97525683038594795e95794cb763aabad83c6df44fcecc0c7e57a8ef45" => :yosemite
    sha256 "76d9ed020e81ff5cd97ca03cba09c7fd94ea27b308ee66829987a003b8c735fe" => :x86_64_linux
  end

  depends_on "metis"
  depends_on "openblas" => (OS.mac? ? :optional : :recommended)

  def install
    args = [
      "INSTALL=#{prefix}",
      "MY_METIS_LIB=-L#{Formula["metis"].opt_lib} -lmetis",
      "MY_METIS_INC=#{Formula["metis"].opt_include}",
    ]
    if build.with? "openblas"
      args << "BLAS=-L#{Formula["openblas"].opt_lib} -lopenblas"
    elsif OS.mac?
      args << "BLAS=-framework Accelerate"
    else
      args << "BLAS=-lblas -llapack"
    end
    args << "LAPACK=$(BLAS)"
    system "make", "library", *args
    system "make", "install", *args
    pkgshare.install "KLU/Demo/klu_simple.c"
  end

  test do
    system ENV.cc, "-o", "test", pkgshare/"klu_simple.c",
                   "-L#{lib}", "-lsuitesparseconfig", "-lklu"
    system "./test"
  end
end