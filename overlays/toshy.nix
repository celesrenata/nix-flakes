final: prev:
rec {
  python-xlib-init = prev.python311.override {
    packageOverrides = final: prev: {
      python-xlib = prev.buildPythonPackage rec {
        pname = "python-xlib";
        version = "0.31";
        format = "pyproject";
        doCheck = false;
        BuildInputs = with prev.pkgs.python311Packages; [
          setuptools
          setuptools-scm
          six
        ];
        src = prev.fetchPypi {
          inherit pname version;
          sha256 = "sha256-dNg6CB9TK8B/bXr81kFuw4QD1o9oubncnh8o+/LXmek=";
        };
      };
    };
  };
  python-xlib = python-xlib-init.pkgs.buildPythonPackage rec {
    pname = "python-xlib";
    version = "0.31";
    format = "pyproject";
    doCheck = false;
    nativeBuildInputs = with python-xlib-init.pkgs; [
      setuptools
      setuptools-scm
      six
    ];
    src = python-xlib-init.pkgs.fetchPypi {
      inherit pname version;
      sha256 = "sha256-dNg6CB9TK8B/bXr81kFuw4QD1o9oubncnh8o+/LXmek=";
    };
  };
  dbus-python-init = prev.pkgs.python311Packages.dbus-python.overrideAttrs ( rec {
    name = "dbus-python-${version}";
    pname = "dbus-python";
    version = "1.3.2";
    src = prev.pkgs.fetchPypi {
      inherit pname version;
      sha256 = "sha256-rWeBkwhhi1BpU3viN/jmjKHH/Mle5KEh/mhFsUGCSPg=";
  };
  });
  dbus-python = dbus-python-init.overrideAttrs ( rec {
    name = "dbus-python-${version}";
    pname = "dbus-python";
    version = "1.3.2";
    src = prev.pkgs.fetchPypi {
      inherit pname version;
      sha256 = "sha256-rWeBkwhhi1BpU3viN/jmjKHH/Mle5KEh/mhFsUGCSPg=";
    };
  });
  python-xwaykeyz-init = prev.python311.override {
    packageOverrides = final: prev: {
      python-xwaykeyz = prev.buildPythonPackage {
        pname = "python-xwaykeyz";
        version = "1.0.0";
        format = "pyproject";
        doCheck = false;
        BuildInputs = with prev.pkgs.python311Packages; [
          python-xlib
          hatchling
          appdirs
          final.dbus-python
          evdev
          hyprpy
          i3ipc
          inotify-simple
          ordered-set
          pywayland
        ];
        propagatedBuildInputs = [
          final.dbus-python
        ];
        src = prev.pkgs.fetchFromGitHub {
          owner = "RedBearAK";
          repo = "xwaykeyz";
          rev = "335cf7490e286e981d11687a93d119b516482376";
          sha256 = "sha256-JX8VLjEopH2MFf65hxKcjbRAPLtNLUh6dWm0pzh/hJg=";
        };
      };
    };
  };
  python-xwaykeyz = python-xwaykeyz-init.pkgs.buildPythonPackage {
    pname = "python-xwaykeyz";
    version = "1.0.0";
    format = "pyproject";
    doCheck = false;
    nativeBuildInputs = with python-xwaykeyz-init.pkgs; [
      final.python-xlib
      hatchling
      appdirs
      final.dbus-python
      evdev
      final.python-hyprpy
      final.python-i3ipc
      inotify-simple
      ordered-set
      pywayland
    ];
    propagatedNativeBuildInputs = [
      final.dbus-python
    ];
    src = prev.pkgs.fetchFromGitHub {
      owner = "RedBearAK";
      repo = "xwaykeyz";
      rev = "335cf7490e286e981d11687a93d119b516482376";
      sha256 = "sha256-JX8VLjEopH2MFf65hxKcjbRAPLtNLUh6dWm0pzh/hJg=";
    };
  };

  python-hyprpy-init = prev.python311.override {
    packageOverrides = final: prev: {
      python-hyprpy = prev.buildPythonPackage rec {
        pname = "hyprpy";
        version = "0.1.5";
        format = "pyproject";
        doCheck = false;
        BuildInputs = with prev.pkgs.python311Packages; [
          setuptools
          pydantic
        ];
        src = prev.fetchPypi {
          inherit pname version;
          sha256 = "sha256-yyPPnIc1CXL3Aqo6q+45uMNfU8DeUxjRgScruqDIJHA";
        };
      };
    };
  };
  python-hyprpy = python-hyprpy-init.pkgs.buildPythonPackage rec {
    pname = "hyprpy";
    version = "0.1.5";
    format = "pyproject";
    doCheck = false;
    nativeBuildInputs = with python-hyprpy-init.pkgs; [
      setuptools
      pydantic
    ];
    src = python-hyprpy-init.pkgs.fetchPypi {
      inherit pname version;
      sha256 = "sha256-yyPPnIc1CXL3Aqo6q+45uMNfU8DeUxjRgScruqDIJHA";
    };
  };
  python-i3ipc-init = prev.python311.override {
    packageOverrides = final: prev: {
      python-i3ipc = prev.buildPythonPackage rec {
        pname = "i3ipc";
        version = "2.2.1";
        format = "pyproject";
        doCheck = false;
        BuildInputs = with prev.pkgs.python311Packages; [
          setuptools
          python-xlib
          pytest
          yapf
          flake8
          sphinx
          sphinxcontrib-asyncio
          shpinxcontrib-fulltoc
        ];
        src = prev.fetchPypi {
          inherit pname version;
          sha256 = "sha256-6IDX1xR5WerVyzR2Twi5e0E4WzbrglborxzhY9vMzOg=";
        };
      };
    };
  };
  python-i3ipc = python-i3ipc-init.pkgs.buildPythonPackage rec {
    pname = "i3ipc";
    version = "2.2.1";
    format = "pyproject";
    doCheck = false;
    nativeBuildInputs = with python-i3ipc-init.pkgs; [
      setuptools
      final.python-xlib
      pytest
      yapf
      flake8
      sphinx
      sphinxcontrib-asyncio
      sphinxcontrib-fulltoc
    ];
    src = python-i3ipc-init.pkgs.fetchPypi {
      inherit pname version;
      sha256 = "sha256-6IDX1xR5WerVyzR2Twi5e0E4WzbrglborxzhY9vMzOg=";
    };
  };
  python-tk-init = prev.python311.override {
    packageOverrides = final: prev: {
      python-tk = prev.buildPythonPackage rec {
        pname = "tk";
        version = "0.1.0";
        format = "pyproject";
        doCheck = false;
        BuildInputs = [
          prev.pkgs.python311Packages.setuptools
        ];
        src = prev.fetchPypi {
          inherit pname version;
          sha256 = "sha256-YLyJI9XTX2f1xr2T1PDEnSBIEU7Ad3aPlZrvNtTtl/g=";
        };
      };
    };
  };
  python-tk = python-tk-init.pkgs.buildPythonPackage rec {
    pname = "tk";
    version = "0.1.0";
    format = "pyproject";
    doCheck = false;
    nativeBuildInputs = [
      python-tk-init.pkgs.setuptools
    ];
    src = python-tk-init.pkgs.fetchPypi {
      inherit pname version;
      sha256 = "sha256-YLyJI9XTX2f1xr2T1PDEnSBIEU7Ad3aPlZrvNtTtl/g=";
    };
  };
  python-toshy-init = prev.python311.override {
    packageOverrides = final: prev: {
      xwaykeyz = with prev.pkgs.python3Packages; toPythonApplication final.python-xwaykeyz;
      toshy = prev.buidPythonPackages {
        preBuild = ''
cat > setup.py << EOF
from setuptools import setup

setup(
    name='toshy',
    version='24.0.3',
    packages=['lib', 'wlroots-dbus-service', 'wlroots-dbus-service.wayland_protocols',
              'wlroots-dbus-service.wayland_protocols.wayland',
              'wlroots-dbus-service.wayland_protocols.wlr_foreign_toplevel_management_unstable_v1'],
    url='https://github.com/RedBearAK/toshy',
    license='GPL-3',
    author='RedBearAk',
    author_email='RedBearAK@github.com',
    description='Mac Keybindings for Linux'
)
EOF
        '';
        pname = "toshy";
        version = "24.0.3";
        format = "other";
        build-system = with prev.pkgs.python3Packages; [
          setuptools
          wheel
        ];

        buildInputs = [ prev.pkgs.gtk3 ];

        propagatedBuildInputs = with prev.pkgs.python311Packages; [
          appdirs
          pycairo
          pip
          wheel
          setuptools
          six
          evdev
          inotify-simple
          pillow
          pygobject3
          lockfile
          dbus-python
          systemd
          python-tk
          sv-ttk
          watchdog
          ordered-set
          psutil
          python-hyprpy
          python-i3ipc
          pywayland
          pywlroots
          pydantic
          final.python-xlib
          python-xwaykeyz
        ];
        nativeBuildInputs = with prev.pkgs; [
          gtk3
          wrapGAppsHook
        ];
        dependencies = with prev.pkgs; [
          gtk3
          python311Packages.python-xwaykeyz
        ];

        src = prev.fetchFromGitHub {
          owner = "RedBearAK";
          repo = "toshy";
          rev = "4f528488aeae9a7def52b5a696458b4b310bc512";
          sha256 = "sha256-ZpJti27TA0XXMCyBrguEKvLYI+SQvVmbQYKqbpiJWQk=";
        };
        installPhase = ''
          HOME=$TEMPDIR
          find assets | awk '{ print "install -m755 -D " $0 " ~/.config/toshy/" $0 }' | bash
          find cinnamon-extension | awk '{ print "install -m755 -D " $0 " ~/.config/toshy/" $0 }' | bash
          find default-toshy-config | awk '{ print "install -m755 -D " $0 " ~/.config/toshy/" $0 }' | bash
          find desktop | awk '{ print "install -m755 -D " $0 " ~/.config/toshy/" $0 }' | bash
          find kde-kwin-dbus-service | awk '{ print "install -m755 -D " $0 " ~/.config/toshy/" $0 }' | bash
          find kde-kwin-script | awk '{ print "install -m755 -D " $0 " ~/.config/toshy/" $0 }' | bash
          find lib | awk '{ print "install -m755 -D " $0 " ~/.config/toshy/" $0 }' | bash
          find scripts | awk '{ print "install -m755 -D " $0 " ~/.config/toshy/" $0 }' | bash
          find systemd-user-service-units | awk '{ print "install -m755 -D " $0 " ~/.config/toshy/" $0 }' | bash
          find wlroots-dbus-service | awk '{ print "install -m755 -D " $0 " ~/.config/toshy/" $0 }' | bash
          install -m755 -D toshy_gui.py ~/.config/toshy/toshy_gui.py
          install -m755 -D toshy_tray.py ~/.config/toshy/toshy_tray.py
          find scripts/bin | sed s/\.sh//g | awk -F "/" '{ print "install -m755 -D " $0 ".sh ~/.local/bin" $NF }' 
        '';
      };
    };
  };
      
  xwaykeyz = with prev.pkgs.python3Packages; toPythonApplication final.python-xwaykeyz;
  toshy = prev.pkgs.python311Packages.buildPythonApplication {
    preBuild = ''
cat > setup.py << EOF
from setuptools import setup

setup(
    name='toshy',
    version='24.0.3',
    packages=['lib', 'wlroots-dbus-service', 'wlroots-dbus-service.wayland_protocols',
              'wlroots-dbus-service.wayland_protocols.wayland',
              'wlroots-dbus-service.wayland_protocols.wlr_foreign_toplevel_management_unstable_v1'],
    url='https://github.com/RedBearAK/toshy',
    license='GPL-3',
    author='RedBearAk',
    author_email='RedBearAk@github.com',
    description='Mac Keybindings for Linux'
)
EOF
    '';
    pname = "toshy";
    version = "24.0.3";
    format = "other";
    build-system = with prev.pkgs.python3Packages; [
      setuptools
      wheel
    ];
    buildInputs = [ prev.pkgs.gtk3 ];

    propagatedBuildInputs = with prev.pkgs.python311Packages; [
      appdirs
      pycairo
      pip
      evdev
      inotify-simple
      wheel
      setuptools
      six
      ordered-set
      pillow
      pygobject3
      lockfile
      dbus-python
      systemd
      final.python-tk
      sv-ttk
      watchdog
      psutil 
      final.python-hyprpy
      final.python-i3ipc
      pywayland
      pywlroots
      pydantic
      final.python-xlib
      final.python-xwaykeyz
    ];
    nativeBuildInputs = with prev.pkgs; [
      gtk3
      wrapGAppsHook
    ];
    dependencies = [
      prev.pkgs.gtk3
      xwaykeyz
    ];
    installPhase = ''
      HOME=$TEMPDIR
      find assets | awk '{ print "install -m755 -D " $0 " ~/.config/toshy/" $0 }' | bash
      find cinnamon-extension | awk '{ print "install -m755 -D " $0 " ~/.config/toshy/" $0 }' | bash
      find default-toshy-config | awk '{ print "install -m755 -D " $0 " ~/.config/toshy/" $0 }' | bash
      find desktop | awk '{ print "install -m755 -D " $0 " ~/.config/toshy/" $0 }' | bash
      find kde-kwin-dbus-service | awk '{ print "install -m755 -D " $0 " ~/.config/toshy/" $0 }' | bash
      find kde-kwin-script | awk '{ print "install -m755 -D " $0 " ~/.config/toshy/" $0 }' | bash
      find lib | awk '{ print "install -m755 -D " $0 " ~/.config/toshy/" $0 }' | bash
      find scripts | awk '{ print "install -m755 -D " $0 " ~/.config/toshy/" $0 }' | bash
      find systemd-user-service-units | awk '{ print "install -m755 -D " $0 " ~/.config/toshy/" $0 }' | bash
      find wlroots-dbus-service | awk '{ print "install -m755 -D " $0 " ~/.config/toshy/" $0 }' | bash
      install -m755 -D toshy_gui.py ~/.config/toshy/toshy_gui.py
      install -m755 -D toshy_tray.py ~/.config/toshy/toshy_tray.py
      find scripts/bin | sed s/\.sh//g | awk -F "/" '{ print "install -m755 -D " $0 ".sh ~/.local/bin" $NF }' 
    '';
    src = prev.pkgs.fetchFromGitHub {
      owner = "RedBearAK";
      repo = "toshy";
      rev = "39ed934b9a700a58e796f7a45b9a8dbaabec393c";
      sha256 = "sha256-ZpJti27TA0XXMCyBrguEKvlYI+SQvVmbQYKqbpiJWQk=";
    }; 
  };
}