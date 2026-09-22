# Hyte Touch Display User Service
{ inputs, lib, pkgs, config, ... }:

let
  pythonWithAudio = pkgs.python3.withPackages (ps: with ps; [ numpy scipy ]);
  hyteTouchConfig = pkgs.runCommand "hyte-touch-quickshell" { } ''
    cp -r ${inputs.hyte-touch-infinite-flakes}/config/quickshell $out
    chmod -R u+w $out
    cp ${./hyte-system-monitor.sh} $out/system-monitor.sh
    chmod +x $out/system-monitor.sh
    substituteInPlace $out/widgets/MusicVisualizerWidget.qml \
      --replace-fail "running: true" "running: false" \
      --replace-fail "Text {" "Text { visible: false" \
      --replace-fail "Row {" "Row { visible: false"
    substituteInPlace $out/shell.qml \
      --replace-fail "opacity: 0.3  // Very transparent background" "opacity: 0.12  // Drift remains visible behind widgets" \
      --replace-fail "opacity: 0.85  // Widgets more opaque for readability" "opacity: 0.68  // Balance dashboard readability with Drift" \
      --replace-fail 'width: parent.width * 0.5' 'width: (parent.width - parent.spacing) / 2' \
      --replace-fail $'Row {\n                                anchors.top: parent.top\n                                anchors.left: parent.left\n                                anchors.right: parent.right\n                                anchors.topMargin: 0\n                                anchors.leftMargin: 10\n                                anchors.rightMargin: 10\n                                height: parent.height * 0.15\n                                spacing: 10' $'Item {\n                                anchors.top: parent.top\n                                anchors.left: parent.left\n                                anchors.right: parent.right\n                                anchors.topMargin: 0\n                                anchors.leftMargin: 10\n                                anchors.rightMargin: 10\n                                height: parent.height * 0.15' \
      --replace-fail $'Column {\n                                    width: (parent.width - parent.spacing) / 2' $'Column {\n                                    anchors.top: parent.top\n                                    anchors.left: parent.left\n                                    width: (parent.width - 10) / 2' \
      --replace-fail $'SystemUsageWidget {\n                                    width: (parent.width - parent.spacing) / 2\n                                    height: parent.height' $'SystemUsageWidget {\n                                    anchors.top: parent.top\n                                    anchors.right: parent.right\n                                    width: (parent.width - 10) / 2\n                                    height: parent.height'
    substituteInPlace $out/widgets/SystemUsageWidget.qml \
      --replace-fail 'SystemMonitor.diskReadMB.toFixed(1)' 'Number(SystemMonitor.diskReadMB || 0).toFixed(1)' \
      --replace-fail 'SystemMonitor.diskWriteMB.toFixed(1)' 'Number(SystemMonitor.diskWriteMB || 0).toFixed(1)' \
      --replace-fail 'interval: 2000' 'interval: 250' \
      --replace-fail 'newCpu.length > 30' 'newCpu.length > 240' \
      --replace-fail 'newRam.length > 30' 'newRam.length > 240' \
      --replace-fail 'newGpu.length > 30' 'newGpu.length > 240'
    substituteInPlace $out/widgets/NetworkWidget.qml \
      --replace-fail 'interval: 2000' 'interval: 250'
    substituteInPlace $out/widgets/TemperatureDetailWidget.qml \
      --replace-fail 'interval: 2000' 'interval: 250' \
      --replace-fail 'newHistory.length > 60' 'newHistory.length > 480'
    substituteInPlace $out/SystemMonitor.qml \
      --replace-fail 'property real prevTx: 0' $'property real prevTx: 0\n    property real prevSampleMs: 0' \
      --replace-fail 'var txDelta = tx - root.prevTx' $'var txDelta = tx - root.prevTx\n                    var nowMs = Date.now()\n                    var elapsed = root.prevSampleMs > 0 ? Math.max((nowMs - root.prevSampleMs) / 1000, 0.001) : 0.25' \
      --replace-fail '(rxDelta / 1048576) / 2' '(rxDelta / 1048576) / elapsed' \
      --replace-fail '(txDelta / 1048576) / 2' '(txDelta / 1048576) / elapsed' \
      --replace-fail 'root.prevTx = tx' $'root.prevTx = tx\n                root.prevSampleMs = Date.now()' \
      --replace-fail 'newDown.length > 30' 'newDown.length > 240' \
      --replace-fail 'newUp.length > 30' 'newUp.length > 240' \
      --replace-fail 'interval: 2000' 'interval: 250'
    sed -i '/property real totalDownBytes: 0/a\    Behavior on cpuUsage { NumberAnimation { duration: 320; easing.type: Easing.InOutSine } }\
    Behavior on ramUsage { NumberAnimation { duration: 320; easing.type: Easing.InOutSine } }\
    Behavior on gpuUsage { NumberAnimation { duration: 320; easing.type: Easing.InOutSine } }\
    Behavior on gpuMemUsage { NumberAnimation { duration: 320; easing.type: Easing.InOutSine } }\
    Behavior on diskUsage { NumberAnimation { duration: 320; easing.type: Easing.InOutSine } }\
    Behavior on disk2Usage { NumberAnimation { duration: 320; easing.type: Easing.InOutSine } }\
    Behavior on cpuTemp { NumberAnimation { duration: 320; easing.type: Easing.InOutSine } }\
    Behavior on gpuTemp { NumberAnimation { duration: 320; easing.type: Easing.InOutSine } }\
    Behavior on moboTemp { NumberAnimation { duration: 320; easing.type: Easing.InOutSine } }\
    Behavior on chipsetTemp { NumberAnimation { duration: 320; easing.type: Easing.InOutSine } }\
    Behavior on cpuPower { NumberAnimation { duration: 320; easing.type: Easing.InOutSine } }\
    Behavior on gpuPower { NumberAnimation { duration: 320; easing.type: Easing.InOutSine } }\
    Behavior on netUpMBps { NumberAnimation { duration: 320; easing.type: Easing.InOutSine } }\
    Behavior on netDownMBps { NumberAnimation { duration: 320; easing.type: Easing.InOutSine } }' \
      $out/SystemMonitor.qml
    sed -i '/width: parent.width \* (SystemMonitor\..* \/ 100)/a\                        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }' \
      $out/widgets/SystemUsageWidget.qml
    sed -i '/font.pixelSize: 16/a\                    width: 32\
                    horizontalAlignment: Text.AlignRight\
                    font.family: "monospace"' $out/widgets/SystemUsageWidget.qml
    sed -i \
      -e 's/spacing: 20/width: 240\
            spacing: 12/' \
      -e '/^            Column {$/a\                width: 72' \
      -e '/font.pixelSize: 16/a\                    width: parent.width\
                    horizontalAlignment: Text.AlignRight\
                    font.family: "monospace"' \
      $out/widgets/PowerWidget.qml
    sed -i '/height: Math.max(((modelData.temp - 20) \/ 80) \* parent.height, 0)/a\                                    Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }' \
      $out/widgets/TemperatureWidget.qml
    sed -i '/color: "#1e1e1e"/a\    property real graphMaxRate: 10\
    Behavior on graphMaxRate { NumberAnimation { duration: 900; easing.type: Easing.InOutSine } }\
    Connections {\
        target: SystemMonitor\
        function onNetDownHistoryChanged() {\
            graphMaxRate = Math.max(Math.max(...SystemMonitor.netDownHistory), Math.max(...SystemMonitor.netUpHistory), 10)\
        }\
    }' $out/widgets/NetworkWidget.qml
    sed -i \
      -e 's/interval: 250/interval: 33/' \
      -e '/var maxRate = Math.max(/,/var xStep = /c\                    var maxRate = networkWidget.graphMaxRate\
                    var xStep = width \/ Math.max(SystemMonitor.netDownHistory.length - 1, 1)' \
      -e 's/var x = i \* xStep/var x = (i - SystemMonitor.networkScroll) * xStep/g' \
      $out/widgets/NetworkWidget.qml
    substituteInPlace $out/widgets/RouterWidget.qml \
      --replace-fail 'nix-shell -p net-snmp --run \"snmpget' 'snmpget' \
      --replace-fail 'IF-MIB::ifInOctets.19 IF-MIB::ifOutOctets.19\""]' 'IF-MIB::ifInOctets.19 IF-MIB::ifOutOctets.19"]'
    substituteInPlace $out/widgets/RouterWidget.qml \
      --replace-fail 'IF-MIB::ifInOctets.9 IF-MIB::ifOutOctets.9' 'IF-MIB::ifInOctets.31 IF-MIB::ifOutOctets.31' \
      --replace-fail 'IF-MIB::ifInOctets.10 IF-MIB::ifOutOctets.10' 'IF-MIB::ifInOctets.35 IF-MIB::ifOutOctets.35' \
      --replace-fail 'IF-MIB::ifInOctets.14 IF-MIB::ifOutOctets.14' 'IF-MIB::ifInOctets.43 IF-MIB::ifOutOctets.43' \
      --replace-fail 'IF-MIB::ifInOctets.11 IF-MIB::ifOutOctets.11' 'IF-MIB::ifInOctets.33 IF-MIB::ifOutOctets.33' \
      --replace-fail 'IF-MIB::ifInOctets.13 IF-MIB::ifOutOctets.13' 'IF-MIB::ifInOctets.37 IF-MIB::ifOutOctets.37' \
      --replace-fail 'IF-MIB::ifInOctets.16 IF-MIB::ifOutOctets.16' 'IF-MIB::ifInOctets.39 IF-MIB::ifOutOctets.39' \
      --replace-fail 'IF-MIB::ifInOctets.17 IF-MIB::ifOutOctets.17' 'IF-MIB::ifInOctets.41 IF-MIB::ifOutOctets.41' \
      --replace-fail 'IF-MIB::ifInOctets.18 IF-MIB::ifOutOctets.18' 'IF-MIB::ifInOctets.45 IF-MIB::ifOutOctets.45' \
      --replace-fail 'IF-MIB::ifInOctets.15 IF-MIB::ifOutOctets.15' 'IF-MIB::ifInOctets.47 IF-MIB::ifOutOctets.47' \
      --replace-fail 'IF-MIB::ifInOctets.19 IF-MIB::ifOutOctets.19"]' 'IF-MIB::ifInOctets.49 IF-MIB::ifOutOctets.49 IF-MIB::ifInOctets.9 IF-MIB::ifOutOctets.9"]' \
      --replace-fail 'initialWgOtherIn = wgOtherIn' 'initialWgOtherIn = 0' \
      --replace-fail 'initialWgOtherOut = wgOtherOut' 'initialWgOtherOut = 0' \
      --replace-fail 'initialK8sIn = k8sIn' 'initialK8sIn = 0' \
      --replace-fail 'initialK8sOut = k8sOut' 'initialK8sOut = 0'
    substituteInPlace $out/widgets/NasWidget.qml \
      --replace-fail 'hrStorageSize.57' 'hrStorageSize.56' \
      --replace-fail 'hrStorageUsed.57' 'hrStorageUsed.56'
    sed -i \
      -e 's/ifIndex === 9 || ifIndex === 10 || ifIndex === 14/ifIndex === 31 || ifIndex === 35 || ifIndex === 43/g' \
      -e 's/ifIndex === 11 || ifIndex === 13 || ifIndex === 16 || ifIndex === 17 || ifIndex === 18 || ifIndex === 15/ifIndex === 33 || ifIndex === 37 || ifIndex === 39 || ifIndex === 41 || ifIndex === 45 || ifIndex === 47/g' \
      -e 's/ifIndex === 19/ifIndex === 9/g' \
      -e 's/ifIndex === 47) wgOther/ifIndex === 47 || ifIndex === 49) wgOther/g' \
      $out/widgets/RouterWidget.qml
    sed -i \
      -e '0,/Rectangle {/s//Rectangle {\
    id: routerWidget/' \
      -e '/property var wanInHistory:/i\    property int historyPoints: 1200\
    function emptyHistory() { return [] }' \
      -e '/property var .*History: \[\]/s/\[\]/emptyHistory()/' \
      -e '/property var k8sOutHistory:/a\    property real graphScroll: 1\
    property real wanScale: 1\
    property real vpnScale: 1\
    property real wgOtherScale: 1\
    property real k8sScale: 1\
    Behavior on wanScale { NumberAnimation { duration: 900; easing.type: Easing.InOutSine } }\
    Behavior on vpnScale { NumberAnimation { duration: 900; easing.type: Easing.InOutSine } }\
    Behavior on wgOtherScale { NumberAnimation { duration: 900; easing.type: Easing.InOutSine } }\
    Behavior on k8sScale { NumberAnimation { duration: 900; easing.type: Easing.InOutSine } }\
    NumberAnimation {\
        id: graphScrollAnimation\
        target: routerWidget\
        property: "graphScroll"\
        from: 0\
        to: 1\
        duration: 900\
        easing.type: Easing.InOutSine\
    }' \
      -e 's/> 60)/> historyPoints + 1)/g' \
      -e '/if (k8sOutHistory.length > historyPoints + 1) k8sOutHistory.shift()/a\                        wanScale = Math.max(...wanInHistory, ...wanOutHistory, 1)\
                        vpnScale = Math.max(...vpnInHistory, ...vpnOutHistory, 0.001)\
                        wgOtherScale = Math.max(...wgOtherInHistory, ...wgOtherOutHistory, 0.001)\
                        k8sScale = Math.max(...k8sInHistory, ...k8sOutHistory, 1)\
                        if (wanInHistory.length > historyPoints) graphScrollAnimation.restart()\
                        else graphScroll = 0' \
      -e 's/interval: 5000/interval: 1000/' \
      -e 's/interval: 2000/interval: 33/g' \
      -e 's/var maxVal = Math.max(...wanInHistory, ...wanOutHistory, 1)/var maxVal = wanScale/' \
      -e 's/var maxVal = Math.max(...vpnInHistory, ...vpnOutHistory, 1)/var maxVal = vpnScale/' \
      -e 's/var maxVal = Math.max(...wgOtherInHistory, ...wgOtherOutHistory, 1)/var maxVal = wgOtherScale/' \
      -e 's/var maxVal = Math.max(...k8sInHistory, ...k8sOutHistory, 1)/var maxVal = k8sScale/' \
      -e 's#var x = (i / ([A-Za-z0-9]*History.length - 1)) \* width#var x = ((i - graphScroll) / (Math.max(wanInHistory.length - 1, 1))) * width#g' \
      $out/widgets/RouterWidget.qml
    patch -d $out -p1 < ${./hyte-network-fluid.patch}
  '';
in
{
  # Install Qt WebEngine for embedded browser
  home.packages = with pkgs; [
    qt6.qtwebengine
  ];

  # Deploy touch quickshell config
  home.file.".config/quickshell/touch" = {
    source = hyteTouchConfig;
    recursive = true;
  };

  # Direct QuickShell on DP-3
  systemd.user.services.hyte-touch-display = {
    Unit = {
      Description = "Hyte Touch Display QuickShell";
      After = [ "graphical-session.target" "drift-visualizer.service" ];
      Wants = [ "drift-visualizer.service" ];
      PartOf = [ "graphical-session.target" ];
    };
    
    Service = {
      Type = "simple";
      Environment = "PATH=${pythonWithAudio}/bin:${pkgs.pulseaudio}/bin:/run/current-system/sw/bin";
      ExecStart = "${pkgs.writeShellScript "quickshell-wrapper" ''
        export WAYLAND_DISPLAY=wayland-1
        export QML2_IMPORT_PATH=${pkgs.qt6.qtwebengine}/lib/qt-6/qml
        export QTWEBENGINE_DISABLE_SANDBOX=1
        export QTWEBENGINE_CHROMIUM_FLAGS="--no-sandbox --disable-gpu"
        export GRAFANA_API_TOKEN=$(cat /run/secrets/grafana_api_token)
        exec ${pkgs.quickshell}/bin/quickshell -p /home/celes/.config/quickshell/touch "$@"
      ''}";
      Restart = "always";
      RestartSec = "3s";
    };
    
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
  
  # HelloDJ Drift visualizer running behind QuickShell
  systemd.user.services.drift-visualizer = {
    Unit = {
      Description = "HelloDJ Drift Music Visualizer";
      After = [ "graphical-session.target" "hyprland-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.writeShellScript "drift-wrapper" ''
        export WAYLAND_DISPLAY=wayland-1
        export SDL_VIDEODRIVER=wayland
        export PYTHONPATH=/home/celes/sources/celesrenata/hellodj/platform/components/hls-transcode
        export PATH=${lib.makeBinPath [ pythonWithAudio pkgs.mpvpaper pkgs.pulseaudio ]}:$PATH
        export LD_LIBRARY_PATH=/run/opengl-driver/lib:${lib.makeLibraryPath [ pkgs.libglvnd pkgs.mesa ]}
        exec ${pythonWithAudio}/bin/python /home/celes/sources/celesrenata/hellodj/platform/components/hls-transcode/tools/drift_panel.py \
          --width 682 --height 2560 --preset "Ethereal Mist"
      ''}";
      Restart = "always";
      RestartSec = "3s";
    };
    
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
