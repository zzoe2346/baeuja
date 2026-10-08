# 앱 아이콘

사용자가 선택한 **B안: 노란 배경, 빨간 머리띠 캐릭터와 파란 책**을 적용했습니다. 캐릭터는 사용자가 직접 그린 둥근 머리, 빈 원형 눈과 작은 `^` 입을 참고했습니다. 원본 그림 파일은 공개 저장소에 포함하지 않았습니다.

<img src="Preview/AppIcon-default.png" width="256" alt="적용한 B안의 macOS 아이콘">

## 파일

- `AppIcon.icon/`: Icon Composer에서 편집하는 원본. 전경 PNG와 단색 배경, 위치 및 재질 설정을 포함합니다.
- `Compiled/`: Xcode 27의 `actool`이 만든 `Assets.car`, 이전 macOS용 `AppIcon.icns`, Info.plist 항목과 검증 해시입니다.
- `Preview/AppIcon-default.png`: Icon Composer에서 내보낸 README용 기본 표시 이미지입니다.
- `Candidates/`: 선택 전에 제시한 네 가지 초안 원본입니다. 앱에는 B안만 사용합니다.
- [prompts.json](prompts.json): 생성과 배경 분리의 출처 및 프롬프트입니다.

## 보관한 후보

| A: 책을 읽는 캐릭터 | B: 머리띠와 책, 선택됨 |
|---|---|
| <img src="Candidates/A-reading.png" width="220" alt="A안"> | <img src="Candidates/B-study-headband.png" width="220" alt="B안"> |

| C: 머리띠 얼굴 | D: 책과 책갈피 |
|---|---|
| <img src="Candidates/C-face.png" width="220" alt="C안"> | <img src="Candidates/D-book.png" width="220" alt="D안"> |

## 제작 기준

2026-10-08에 [Apple 앱 아이콘 지침](https://developer.apple.com/design/human-interface-guidelines/app-icons)과 [Icon Composer 안내](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)를 확인했습니다. 생성 이미지에 유리 효과를 그려 넣는 대신 투명 전경과 배경을 분리하고, 시스템 마스크와 Liquid Glass 재질은 Icon Composer와 macOS가 처리하도록 구성했습니다. 손과 머리띠가 잘리지 않도록 전경 배율을 80%로 조정했습니다.

Icon Composer 27에서 Default, Dark와 Mono를 검토했습니다. 색상이 없어도 눈, 머리띠와 책의 형태를 구분할 수 있습니다. 어두운 표시는 시스템이 어두운 배경으로 바꿉니다. 이미지 내보내기는 정적 홍보 이미지이며, 앱은 컴파일된 네이티브 아이콘을 사용합니다. 갱신 명령은 [개발 안내](../../docs/development.md)에 있습니다.
