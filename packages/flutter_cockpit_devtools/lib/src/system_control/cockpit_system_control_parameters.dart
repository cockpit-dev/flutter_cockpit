import 'cockpit_system_control_profile.dart';

final class CockpitSystemControlAllowedValues {
  const CockpitSystemControlAllowedValues._();

  static const iosPrivacyServices = <String>[
    'all',
    'calendar',
    'contacts-limited',
    'contacts',
    'location',
    'location-always',
    'photos-add',
    'photos',
    'media-library',
    'microphone',
    'motion',
    'reminders',
    'siri',
  ];

  static const iosContentSizeCategories = <String>[
    'extra-small',
    'small',
    'medium',
    'large',
    'extra-large',
    'extra-extra-large',
    'extra-extra-extra-large',
    'accessibility-medium',
    'accessibility-large',
    'accessibility-extra-large',
    'accessibility-extra-extra-large',
    'accessibility-extra-extra-extra-large',
    'increment',
    'decrement',
  ];

  static const iosStatusBarDataNetworks = <String>[
    'hide',
    'wifi',
    '3g',
    '4g',
    'lte',
    'lte-a',
    'lte+',
    '5g',
    '5g+',
    '5g-uwb',
    '5g-uc',
  ];

  static const iosStatusBarWifiModes = <String>[
    'searching',
    'failed',
    'active',
  ];

  static const iosStatusBarCellularModes = <String>[
    'notSupported',
    'searching',
    'failed',
    'active',
  ];

  static const iosStatusBarBatteryStates = <String>[
    'charging',
    'charged',
    'discharging',
  ];
}

final class CockpitSystemControlParameterSets {
  const CockpitSystemControlParameterSets._();

  static const coordinate = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'x',
      valueType: CockpitSystemControlParameterType.integer,
      required: true,
      description: 'Screen X coordinate in physical pixels.',
    ),
    CockpitSystemControlParameter(
      name: 'y',
      valueType: CockpitSystemControlParameterType.integer,
      required: true,
      description: 'Screen Y coordinate in physical pixels.',
    ),
  ];

  static const longPress = <CockpitSystemControlParameter>[
    ...coordinate,
    CockpitSystemControlParameter(
      name: 'durationMs',
      valueType: CockpitSystemControlParameterType.integer,
      minimum: 1,
      description: 'Hold duration in milliseconds; default is 800.',
    ),
  ];

  static const drag = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'startX',
      valueType: CockpitSystemControlParameterType.integer,
      required: true,
      description: 'Start screen X coordinate in physical pixels.',
    ),
    CockpitSystemControlParameter(
      name: 'startY',
      valueType: CockpitSystemControlParameterType.integer,
      required: true,
      description: 'Start screen Y coordinate in physical pixels.',
    ),
    CockpitSystemControlParameter(
      name: 'endX',
      valueType: CockpitSystemControlParameterType.integer,
      required: true,
      description: 'End screen X coordinate in physical pixels.',
    ),
    CockpitSystemControlParameter(
      name: 'endY',
      valueType: CockpitSystemControlParameterType.integer,
      required: true,
      description: 'End screen Y coordinate in physical pixels.',
    ),
    CockpitSystemControlParameter(
      name: 'durationMs',
      valueType: CockpitSystemControlParameterType.integer,
      minimum: 1,
      description: 'Drag duration in milliseconds; default is 300.',
    ),
  ];

  static const text = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'text',
      valueType: CockpitSystemControlParameterType.string,
      required: true,
    ),
  ];

  static const key = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'key',
      valueType: CockpitSystemControlParameterType.string,
      required: true,
      description:
          'Platform key token, for example enter, escape, tab, or KEYCODE_ENTER.',
    ),
  ];

  static const url = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'url',
      valueType: CockpitSystemControlParameterType.string,
      required: true,
    ),
  ];

  static const androidApp = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'packageId',
      valueType: CockpitSystemControlParameterType.string,
      description: 'Android package id; top-level appId is also accepted.',
    ),
  ];

  static const iosApp = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'appId',
      valueType: CockpitSystemControlParameterType.string,
      description: 'iOS bundle id; top-level appId is also accepted.',
    ),
  ];

  static const androidGrantPermission = <CockpitSystemControlParameter>[
    ...androidApp,
    CockpitSystemControlParameter(
      name: 'permission',
      valueType: CockpitSystemControlParameterType.string,
      required: true,
      description: 'Android permission name such as android.permission.CAMERA.',
    ),
  ];

  static const iosGrantPermission = <CockpitSystemControlParameter>[
    ...iosApp,
    CockpitSystemControlParameter(
      name: 'permission',
      valueType: CockpitSystemControlParameterType.string,
      required: true,
      allowedValues: CockpitSystemControlAllowedValues.iosPrivacyServices,
      description: 'simctl privacy service; service is also accepted.',
    ),
  ];

  static const browserGrantPermission = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'permission',
      valueType: CockpitSystemControlParameterType.string,
      required: true,
      description:
          'Browser permission token supported by the active browser driver.',
    ),
  ];

  static const androidAppearance = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'appearance',
      valueType: CockpitSystemControlParameterType.string,
      required: true,
      allowedValues: <String>['light', 'dark', 'auto'],
    ),
  ];

  static const iosAppearance = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'appearance',
      valueType: CockpitSystemControlParameterType.string,
      required: true,
      allowedValues: <String>['light', 'dark'],
    ),
  ];

  static const hostAppearance = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'appearance',
      valueType: CockpitSystemControlParameterType.string,
      required: true,
      allowedValues: <String>['light', 'dark'],
    ),
  ];

  static const androidContentSize = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'contentSize',
      valueType: CockpitSystemControlParameterType.string,
      description:
          'Android content size token; required unless fontScale is provided.',
    ),
    CockpitSystemControlParameter(
      name: 'fontScale',
      valueType: CockpitSystemControlParameterType.number,
      minimum: 0.5,
      maximum: 3.5,
      description: 'Android font scale between 0.5 and 3.5.',
    ),
  ];

  static const iosContentSize = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'contentSize',
      valueType: CockpitSystemControlParameterType.string,
      required: true,
      allowedValues: CockpitSystemControlAllowedValues.iosContentSizeCategories,
    ),
  ];

  static const hostContentSize = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'contentSize',
      valueType: CockpitSystemControlParameterType.string,
      description: 'Host accessibility text or content-size token.',
    ),
    CockpitSystemControlParameter(
      name: 'fontScale',
      valueType: CockpitSystemControlParameterType.number,
      minimum: 0.1,
      description: 'Host text scale when supported by the adapter.',
    ),
  ];

  static const location = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'latitude',
      valueType: CockpitSystemControlParameterType.number,
      required: true,
      minimum: -90,
      maximum: 90,
      description: 'Latitude in -90..90.',
    ),
    CockpitSystemControlParameter(
      name: 'longitude',
      valueType: CockpitSystemControlParameterType.number,
      required: true,
      minimum: -180,
      maximum: 180,
      description: 'Longitude in -180..180.',
    ),
    CockpitSystemControlParameter(
      name: 'altitude',
      valueType: CockpitSystemControlParameterType.number,
      description: 'Optional altitude when the platform adapter supports it.',
    ),
  ];

  static const androidOrientation = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'orientation',
      valueType: CockpitSystemControlParameterType.string,
      required: true,
      allowedValues: <String>[
        'portrait',
        'landscape',
        'reversePortrait',
        'reverseLandscape',
        'auto',
      ],
    ),
  ];

  static const browserOrientation = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'orientation',
      valueType: CockpitSystemControlParameterType.string,
      required: true,
      allowedValues: <String>['portrait', 'landscape'],
      description: 'Viewport or screen orientation emulation when supported.',
    ),
  ];

  static const iosOrientation = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'orientation',
      valueType: CockpitSystemControlParameterType.string,
      required: true,
      allowedValues: <String>[
        'portrait',
        'landscape',
        'reversePortrait',
        'reverseLandscape',
      ],
    ),
  ];

  static const androidNetworkSpeed = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'networkSpeed',
      valueType: CockpitSystemControlParameterType.string,
      required: true,
      allowedValues: <String>[
        'gsm',
        'hscsd',
        'gprs',
        'edge',
        'umts',
        'hsdpa',
        'lte',
        'evdo',
        'full',
      ],
    ),
  ];

  static const androidNetworkDelay = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'networkDelay',
      valueType: CockpitSystemControlParameterType.string,
      required: true,
      allowedValues: <String>['gprs', 'edge', 'umts', 'none'],
    ),
  ];

  static const hostNetworkSpeed = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'networkSpeed',
      valueType: CockpitSystemControlParameterType.string,
      required: true,
      description: 'Host network shaping profile supported by local tooling.',
    ),
  ];

  static const hostNetworkDelay = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'networkDelay',
      valueType: CockpitSystemControlParameterType.string,
      required: true,
      description: 'Host network delay profile supported by local tooling.',
    ),
  ];

  static const iosStatusBar = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'time',
      valueType: CockpitSystemControlParameterType.string,
      description: 'Fixed iOS simulator status bar time.',
    ),
    CockpitSystemControlParameter(
      name: 'dataNetwork',
      valueType: CockpitSystemControlParameterType.string,
      allowedValues: CockpitSystemControlAllowedValues.iosStatusBarDataNetworks,
    ),
    CockpitSystemControlParameter(
      name: 'wifiMode',
      valueType: CockpitSystemControlParameterType.string,
      allowedValues: CockpitSystemControlAllowedValues.iosStatusBarWifiModes,
    ),
    CockpitSystemControlParameter(
      name: 'wifiBars',
      valueType: CockpitSystemControlParameterType.integer,
      minimum: 0,
      maximum: 3,
      description: 'Wi-Fi bars, 0-3.',
    ),
    CockpitSystemControlParameter(
      name: 'cellularMode',
      valueType: CockpitSystemControlParameterType.string,
      allowedValues:
          CockpitSystemControlAllowedValues.iosStatusBarCellularModes,
    ),
    CockpitSystemControlParameter(
      name: 'cellularBars',
      valueType: CockpitSystemControlParameterType.integer,
      minimum: 0,
      maximum: 4,
      description: 'Cellular bars, 0-4.',
    ),
    CockpitSystemControlParameter(
      name: 'operatorName',
      valueType: CockpitSystemControlParameterType.string,
    ),
    CockpitSystemControlParameter(
      name: 'batteryState',
      valueType: CockpitSystemControlParameterType.string,
      allowedValues:
          CockpitSystemControlAllowedValues.iosStatusBarBatteryStates,
    ),
    CockpitSystemControlParameter(
      name: 'batteryLevel',
      valueType: CockpitSystemControlParameterType.integer,
      minimum: 0,
      maximum: 100,
      description: 'Battery level, 0-100.',
    ),
  ];

  static const screenshot = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'name',
      valueType: CockpitSystemControlParameterType.string,
      description: 'Artifact name; default is system-screenshot.',
    ),
    CockpitSystemControlParameter(
      name: 'outputPath',
      valueType: CockpitSystemControlParameterType.string,
      description: 'Optional path to copy the captured image to.',
    ),
  ];

  static const startRecording = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'name',
      valueType: CockpitSystemControlParameterType.string,
      description: 'Recording artifact name; default is system-recording.',
    ),
    CockpitSystemControlParameter(
      name: 'purpose',
      valueType: CockpitSystemControlParameterType.string,
      allowedValues: <String>['acceptance', 'repro'],
      description: 'Recording purpose; default is acceptance.',
    ),
    CockpitSystemControlParameter(
      name: 'mode',
      valueType: CockpitSystemControlParameterType.string,
      allowedValues: <String>['auto', 'cheap', 'native', 'full'],
      description: 'Recording mode; default is native.',
    ),
    CockpitSystemControlParameter(
      name: 'layer',
      valueType: CockpitSystemControlParameterType.string,
      allowedValues: <String>['flutter', 'app-window', 'host-screen', 'system'],
      description: 'Recording layer; default is system.',
    ),
  ];

  static const stopRecording = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'outputPath',
      valueType: CockpitSystemControlParameterType.string,
      description: 'Optional path to copy the completed recording to.',
    ),
  ];

  static const readUiTree = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'maxDepth',
      valueType: CockpitSystemControlParameterType.integer,
      minimum: 1,
      description: 'Maximum accessibility tree depth; default is 4.',
    ),
    CockpitSystemControlParameter(
      name: 'maxNodes',
      valueType: CockpitSystemControlParameterType.integer,
      minimum: 1,
      description: 'Maximum accessibility nodes; default is 120.',
    ),
  ];

  static const shellCommand = <CockpitSystemControlParameter>[
    CockpitSystemControlParameter(
      name: 'command',
      valueType: CockpitSystemControlParameterType.stringList,
      required: true,
      description: 'Executable plus arguments, for example ["echo","ok"].',
    ),
  ];
}
