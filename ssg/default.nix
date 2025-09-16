{ mkDerivation, base, filepath, hakyll, hlint, lib, pandoc, slugger
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
  testHaskellDepends = [ base hlint ];
  license = lib.licenses.bsd3;
  mainProgram = "hakyll-site";
}
