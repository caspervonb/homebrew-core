class Vtk < Formula
  desc "Toolkit for 3D computer graphics, image processing, and visualization."
  homepage "https://www.vtk.org/"
  url "https://www.vtk.org/files/release/8.0/VTK-8.0.1.tar.gz"
  sha256 "49107352923dea6de05a7b4c3906aaf98ef39c91ad81c383136e768dcf304069"

  head "https://github.com/Kitware/VTK.git"

  bottle do
    sha256 "82ffb47c5d65a168ffc2fe0aa22bcf72a04b666cd62501f538829b64240a142b" => :high_sierra
    sha256 "fc0c622b9cbe231f6bd6ae06f6ab39ccef01f95b28238439d8cf02041a56204b" => :sierra
    sha256 "3aa06ce8d7e3f1d781d56018f2daaea1705b9440c5b5b6eabb826dfe946749c3" => :el_capitan
    sha256 "0ec79613df46e73d166fe6341c5697ea9f6f84be1f933c0d334c436b8481148e" => :yosemite
    sha256 "eb040479efa650e4d91a8ebe7e0a343a6a40e8eef9b1f822f91467782a97261b" => :x86_64_linux
  end

  option "without-python", "Build without python2 support"

  depends_on "cmake" => :build
  depends_on "boost"
  depends_on "fontconfig"
  depends_on "hdf5"
  depends_on "jpeg"
  depends_on "libpng"
  depends_on "libtiff"
  depends_on "netcdf"
  depends_on :python => :recommended if MacOS.version <= :snow_leopard
  depends_on :python3 => :optional
  depends_on "qt" => :optional
  depends_on "pyqt" if build.with? "qt"

  unless OS.mac?
    depends_on "expat"
    depends_on "libxml2"
    depends_on "szip"
    depends_on "zlib"
    depends_on "tcl-tk"
    depends_on :x11
    depends_on "linuxbrew/xorg/mesa"
  end

  needs :cxx11

  def install
    dylib = OS.mac? ? "dylib" : "so"

    args = std_cmake_args + %W[
      -DBUILD_SHARED_LIBS=ON
      -DBUILD_TESTING=OFF
      -DCMAKE_INSTALL_NAME_DIR:STRING=#{lib}
      -DCMAKE_INSTALL_RPATH:STRING=#{lib}
      -DModule_vtkInfovisBoost=ON
      -DModule_vtkInfovisBoostGraphAlgorithms=ON
      -DModule_vtkRenderingFreeTypeFontConfig=ON
      -DVTK_REQUIRED_OBJCXX_FLAGS=''
      -DVTK_USE_SYSTEM_EXPAT=ON
      -DVTK_USE_SYSTEM_HDF5=ON
      -DVTK_USE_SYSTEM_JPEG=ON
      -DVTK_USE_SYSTEM_LIBXML2=ON
      -DVTK_USE_SYSTEM_NETCDF=ON
      -DVTK_USE_SYSTEM_PNG=ON
      -DVTK_USE_SYSTEM_TIFF=ON
      -DVTK_USE_SYSTEM_ZLIB=ON
      -DVTK_WRAP_TCL=ON
    ]
    args << "-DVTK_USE_COCOA=" + (OS.mac? ? "ON" : "OFF")

    unless MacOS::CLT.installed?
      # We are facing an Xcode-only installation, and we have to keep
      # vtk from using its internal Tk headers (that differ from OSX's).
      args << "-DTK_INCLUDE_PATH:PATH=#{MacOS.sdk_path}/System/Library/Frameworks/Tk.framework/Headers"
      args << "-DTK_INTERNAL_PATH:PATH=#{MacOS.sdk_path}/System/Library/Frameworks/Tk.framework/Headers/tk-private"
    end

    mkdir "build" do
      if build.with?("python3") && build.with?("python")
        # VTK Does not support building both python 2 and 3 versions
        odie "VTK: Does not support building both python 2 and 3 wrappers"
      elsif build.with?("python") || build.with?("python3")
        python_executable = `which python`.strip if build.with? "python"
        python_executable = `which python3`.strip if build.with? "python3"

        python_prefix = `#{python_executable} -c 'import sys;print(sys.prefix)'`.chomp
        python_include = `#{python_executable} -c 'from distutils import sysconfig;print(sysconfig.get_python_inc(True))'`.chomp
        python_version = "python" + `#{python_executable} -c 'import sys;print(sys.version[:3])'`.chomp
        py_site_packages = "#{lib}/#{python_version}/site-packages"

        args << "-DVTK_WRAP_PYTHON=ON"
        args << "-DPYTHON_EXECUTABLE='#{python_executable}'"
        args << "-DPYTHON_INCLUDE_DIR='#{python_include}'"
        # CMake picks up the system's python dylib, even if we have a brewed one.
        if File.exist? "#{python_prefix}/Python"
          args << "-DPYTHON_LIBRARY='#{python_prefix}/Python'"
        elsif File.exist? "#{python_prefix}/lib/lib#{python_version}.a"
          args << "-DPYTHON_LIBRARY='#{python_prefix}/lib/lib#{python_version}.a'"
        elsif File.exist? "#{python_prefix}/lib/lib#{python_version}.#{dylib}"
          args << "-DPYTHON_LIBRARY='#{python_prefix}/lib/lib#{python_version}.#{dylib}'"
        elsif File.exist? "#{python_prefix}/lib/x86_64-linux-gnu/lib#{python_version}.#{dylib}"
          args << "-DPYTHON_LIBRARY='#{python_prefix}/lib/x86_64-linux-gnu/lib#{python_version}.so'"
        else
          odie "No libpythonX.Y.{dylib|so|a} file found!"
        end
        # Set the prefix for the python bindings to the Cellar
        args << "-DVTK_INSTALL_PYTHON_MODULE_DIR='#{py_site_packages}/'"
      end

      if build.with? "qt"
        args << "-DVTK_QT_VERSION:STRING=5" << "-DVTK_Group_Qt=ON"
        args << "-DVTK_WRAP_PYTHON_SIP=ON"
        args << "-DSIP_PYQT_DIR='#{Formula["pyqt5"].opt_share}/sip'"
      end

      system "cmake", "..", *args
      system "make"
      system "make", "install"
    end
  end

  def caveats; <<~EOS
    Even without the --with-qt option, you can display native VTK render windows
    from python. Alternatively, you can integrate the RenderWindowInteractor
    in PyQt5, Tk or Wx at runtime. Read more:
      import vtk.qt5; help(vtk.qt5) or import vtk.wx; help(vtk.wx)
    EOS
  end

  test do
    (testpath/"version.cpp").write <<-EOS
      #include <vtkVersion.h>
      #include <assert.h>
      int main(int, char *[]) {
        assert (vtkVersion::GetVTKMajorVersion()==8);
        assert (vtkVersion::GetVTKMinorVersion()==0);
        return EXIT_SUCCESS;
      }
    EOS

    system ENV.cxx, "version.cpp", "-I#{opt_include}/vtk-8.0"
    system "./a.out"
    system "#{bin}/vtkpython", "-c", "exit()"
  end
end
