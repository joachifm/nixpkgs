{ lib, fetchurl, buildPythonPackage, libusb1, udev, cython }:

buildPythonPackage rec {
  pname = "hidapi";
  version = "0.7.99.post20";
  name = "${pname}-${version}";

  src = fetchurl {
    url = "mirror://pypi/h/${pname}/${name}.tar.gz";
    sha256 = "1k7z5m7xsqy8j4qkjy4pfxdx4hm36ha68vi65z6smvnyg4zgv22z";
  };

  propagatedBuildInputs = [ libusb1 udev cython ];

  # Fix the USB backend library lookup
  postPatch = ''
    libusb=${libusb1.dev}/include/libusb-1.0
    test -d $libusb || { echo "ERROR: $libusb doesn't exist, please update/fix this build expression."; exit 1; }
    sed -i -e "s|/usr/include/libusb-1.0|$libusb|" setup.py
  '';

  meta = {
    description = "A Cython interface to the hidapi from https://github.com/signal11/hidapi";
    homepage = https://github.com/trezor/cython-hidapi;
    # license can actually be either bsd3 or gpl3
    # see https://github.com/trezor/cython-hidapi/blob/master/LICENSE-orig.txt
    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [ np ];
  };
}
