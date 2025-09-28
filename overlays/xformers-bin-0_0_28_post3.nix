final: prev: {
  python312Packages = prev.python312Packages // {
    xformers_0_0_28_post3_bin = prev.python312Packages.buildPythonPackage rec {
      pname = "xformers-local";
      version = "0.0.28.post3";
      format = "wheel";

      src = prev.fetchurl {
        url = "https://files.pythonhosted.org/packages/01/ba/048171c15dfd4f9bff63aaf6e93586ea1ea3e14cc66cd2cea59a50fc2047/xformers-0.0.28.post3-cp312-cp312-manylinux_2_28_x86_64.whl";
        sha256 = "0fla44pjyad122kkb7xrns1aq9qxyjvp54kyhjynfnz5nhmzfl65";
      };

      propagatedBuildInputs = with prev.python312Packages; [
        torch
        numpy
      ];

      pythonImportsCheck = [ "xformers" ];

      meta = with prev.lib; {
        description = "Hackable and optimized Transformers building blocks";
        homepage = "https://github.com/facebookresearch/xformers";
        license = licenses.bsd3;
        platforms = platforms.linux;
      };
    };
  };
}
