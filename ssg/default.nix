{ mkDerivation, base, filepath, hakyll, lib, pandoc, slugger
, tagsoup, text
}:
mkDerivation {
  pname = "ssg";
  version = "0.1.0.0";
  src = ./.;
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    base filepath hakyll pandoc slugger tagsoup text
  ];
  license = lib.licenses.bsd3;
  mainProgram = "hakyll-site";
}
