# 개발 안내

Swift Package Manager로 빌드하는 Swift 전용 macOS 앱입니다. SwiftUI와 AppKit으로 화면을 구성하고, Foundation 모델과 원자적 JSON 저장을 사용합니다. 구현 구조와 데이터 계약은 [상세설계](lld.md)를 따릅니다.

그림은 앱 안의 로컬 WebKit으로 렌더링하며, PDF는 AppKit, CoreText와 CoreGraphics로 생성합니다. Python 백엔드나 별도 HTTP 서버는 없습니다. 패키징 도구는 리소스를 포함하는 `.app`을 만들고 실행 파일의 SDK와 최소 OS 기록을 검증합니다.

## 빌드 환경

빌드에는 Swift 6 도구와 macOS 26 이상 SDK가 필요합니다. Xcode 또는 Command Line Tools를 사용할 수 있습니다. 아이콘 원본을 다시 컴파일할 때는 아래 아이콘 갱신 안내에 따라 Xcode를 선택합니다.

## 앱 이름과 호환성

SPM 패키지와 실행 타깃은 `Baeuja`, 빌드 번들은 `dist.noindex/배우자.app`입니다. `AppResources/ko.lproj`와 `en.lproj`의 `InfoPlist.strings`로 한국어 **배우자**, 영어 **Let’s Learn**을 표시합니다.

기존 사용자의 교재와 환경설정을 이어 쓰기 위해 bundle identifier와 저장 경로는 유지합니다. 이전 이름이 들어간 이 두 호환성 식별자를 일괄 문자열 치환하면 기존 보관함이나 설정을 찾지 못할 수 있습니다. 이름 변경 결정은 [002: 배우자 이름과 기존 데이터 호환](decisions/002-product-name.md)에 정리했습니다.

## 앱 설치와 개발용 사본

평소 사용하는 앱의 설치 위치는 `/Applications/배우자.app`으로 통일합니다. `PackageApp`은 설치된 앱을 자동으로 바꾸지 않고 `dist.noindex/`에 빌드 결과를 만듭니다. 기존 `dist/`는 이전 결과물이며 새 빌드 위치가 아닙니다.

업데이트할 때는 진행 중인 생성이 끝난 뒤 앱을 정상 종료하고, 기존 설치 번들을 압축 백업한 다음 새 번들로 교체합니다. bundle identifier `com.zzoe.study-swift`와 기존 `StudySwift` 보관함을 유지하고, 설치본의 서명과 버전, 재실행 후 과정과 메모를 확인합니다. QA용 식별자를 평소 쓰는 설치본에 적용하지 않습니다.

QA 앱은 격리된 보관함과 별도 식별자로 `work/qa-apps.noindex/` 아래에서 실행합니다. 검토가 끝나면 종료하고 필요한 번들만 ZIP으로 보관합니다. 업데이트 백업도 실행 가능한 `.app` 디렉터리를 여러 위치에 남기지 않고 압축합니다. `.gitignore`는 Git 추적만 막으며 검색 제외 설정이 아닙니다. `.noindex` 밖의 개발 폴더를 검색에서 제외해야 할 때는 [Apple의 Spotlight 검색 제외 안내](https://support.apple.com/en-gb/guide/mac-help/mchl1bb43b84/26/mac/26)를 따릅니다. 이 안내와 현재 Mac의 검색 결과는 2026-10-14에 확인했습니다.

## 버전과 변경 이력

[AppResources/version.json](../AppResources/version.json)이 앱 버전과 빌드 번호의 원본입니다. `PackageApp`이 이를 읽어 `CFBundleShortVersionString`과 `CFBundleVersion`에 넣습니다. 예를 들어 `0.1.1 (4)`는 앱 버전 0.1.1의 빌드 4입니다. 설치하거나 전달할 새 빌드는 번호를 증가시키며 같은 소스로 검사를 반복할 때는 증가시키지 않습니다. 빌드 번호는 버전이 바뀌어도 되돌리지 않습니다.

| 변경 | 앱 버전 예시 |
|---|---|
| 버그 수정과 배포 정리 | `0.1.0` → `0.1.1` |
| 학습 기능 추가 | `0.1.1` → `0.2.0` |
| 첫 안정 배포 또는 이후 호환성을 깨는 변경 | `0.x.y` → `1.0.0`, 이후 major 증가 |

0.x에서는 아직 안정화 중임을 나타내며 저장 형식 변경은 버전 숫자와 별도로 이전 설계와 검증이 필요합니다. 버전 규칙은 이 앱의 운영 선택입니다.

[CHANGELOG.md](../CHANGELOG.md)는 사용자에게 달라지는 기능, 수정과 필요한 이전 안내를 버전, 날짜와 함께 기록합니다. 작업 중에는 `미배포`에 추가하고 배포할 때 버전 절로 옮깁니다. Git 커밋은 구현의 변경 단위이고, 한 앱 버전에는 검증된 여러 커밋이 포함될 수 있습니다. [QA 기록](qa.md)은 검사 환경, 결과와 한계를 기록하며 변경 이력과 구분합니다.

배포 순서는 버전과 빌드 번호 갱신, 변경 이력 정리, `./scripts/check.sh`, 커밋, 깨끗한 작업 트리에서 다시 패키징, 설치와 재개 검증, 검증된 커밋의 `v0.1.1` 형식 태그입니다. 태그는 다시 다른 커밋으로 옮기지 않습니다. 번들에는 `BaeujaSourceRevision`과 `BaeujaSourceModified`도 기록합니다. Git 정보가 없는 소스 사본에서는 revision을 `unknown`으로 표시하므로 정식 배포는 Git 체크아웃에서 만듭니다.

2026-10-14에 Apple 공식 [앱 버전](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleshortversionstring)과 [빌드 버전](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleversion) 문서를 확인했습니다. 앱 버전은 세 정수, 빌드는 증가하는 단일 정수로 사용합니다. 기존 앱 정보 창이 이 값을 표시하며 새 화면은 추가하지 않습니다.

## 공통 검사

```sh
./scripts/format.sh
./scripts/check.sh
```

`format.sh`는 소스를 포맷합니다. `check.sh`는 포맷과 SwiftLint, 구조 검사, 문서 링크, 스크린샷 기록, 테스트와 Release 패키징을 확인합니다. 첫 실행에서 공식 SwiftLint 배포의 SHA-256을 확인하고 `.tools/`에 받습니다. 상세 규칙과 실제 화면의 완료 조건은 [품질 기준](quality.md)에 있습니다.

GitHub Actions도 같은 명령과 고정 샘플 QA를 실행합니다. 자동 검사에는 실제 AI 호출이 포함되지 않으며, 합격만으로 학습 내용의 정확성이나 화면 품질, 체감 성능을 보증하지 않습니다.

## AI 에이전트로 개발하기

개발 지침은 도구와 관계없이 [AGENTS.md](../AGENTS.md)를 기준으로 합니다. Claude Code와 Gemini CLI의 진입 파일은 이 지침을 import하고, Cursor와 Copilot의 연결 방식은 [에이전트 운영 안내](agent-workflow.md)에 정리했습니다. 도구를 바꿀 때 지침 로딩과 현재 Git 상태를 확인하세요. 앱의 교재 생성에 사용하는 Codex CLI와 개발 에이전트 선택은 별개입니다.

## 교재 QA

```sh
swift run RunTests
swift run StudyQA --data-dir ./work/local-qa --render-demo --stress-pdf --reopen
```

`RunTests`는 Swift Testing을 실행합니다. Command Line Tools에서는 필요한 매크로 플러그인을 자동으로 찾습니다. 로컬 QA는 AI 없이 그림과 PDF를 만들고 페이지 PNG를 QA 폴더에 저장합니다.

다음 첫 명령은 실제 구독을 사용합니다. 이후 명령은 저장된 자료를 재사용합니다.

```sh
swift run StudyQA --data-dir ./work/live-qa --live --live-image
swift run StudyQA --data-dir ./work/live-qa --reopen --export-saved
swift run StudyQA --data-dir ./work/live-qa --verify-saved-visuals
```

실제 수행 결과와 미확인 항목은 [QA 기록](qa.md), 캡처 출처는 [스크린샷 기록](assets/screenshots.json)을 확인하세요.

## 프로젝트 문서

- [협업 지침과 Git 규칙](../AGENTS.md)
- [에이전트 진입점과 문서 규약](agent-workflow.md)
- [제품 요구사항](requirements.md)
- [상세설계](lld.md)
- [품질 기준](quality.md)
- [OS와 SDK 호환성](compatibility.md)
- [유지보수 구조 결정](decisions/001-maintenance.md)
- [macOS 디자인 기준](design.md)
- [디자인 스킬 검토](design-review.md)
- [앱 아이콘 원본과 후보](../Artwork/AppIcon/README.md)

## 아이콘 갱신

[AppIcon.icon](../Artwork/AppIcon/AppIcon.icon/icon.json)은 Icon Composer에서 만든 편집 가능한 원본입니다. 노란 배경 위에 캐릭터와 책을 하나의 전경 레이어로 배치했습니다. 기본 패키징은 저장소에 포함된 Apple 도구의 컴파일 결과를 사용하므로 Command Line Tools에서도 실행됩니다. 원본과 결과의 SHA-256이 달라지면 오래된 아이콘을 넣지 않고 실패합니다.

원본을 편집한 뒤 Xcode 27 이상을 선택해 다시 컴파일합니다. 전역 `xcode-select` 설정을 바꿀 필요는 없습니다.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run PackageApp --release --refresh-icon
```

Icon Composer의 이미지 내보내기로 README용 [PNG](../Artwork/AppIcon/Preview/AppIcon-default.png)도 갱신합니다. 원본, `Compiled/`의 결과와 해시를 같은 커밋에 포함하고 Finder, Dock과 앱 정보의 아이콘을 실제로 확인합니다. PNG를 앱에 덮어씌우는 코드를 추가하면 시스템 아이콘 재질과 표시 변형을 잃을 수 있으므로 사용하지 않습니다.
