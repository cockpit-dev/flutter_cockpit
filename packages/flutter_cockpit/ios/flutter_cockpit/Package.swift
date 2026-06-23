// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "flutter_cockpit",
  platforms: [
    .iOS("13.0"),
  ],
  products: [
    .library(name: "flutter-cockpit", targets: ["flutter_cockpit"]),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "flutter_cockpit",
      dependencies: [],
      resources: [
        .process("PrivacyInfo.xcprivacy"),
      ]
    ),
  ]
)
