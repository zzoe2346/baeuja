# macOS 디자인 기준

2026-10-08 사용자 요청에 따라 Apple의 현재 HIG와 Liquid Glass 문서를 확인하고 SwiftUI 네이티브 화면을 개선했다. 제품 계약은 [요구사항](requirements.md), 실제 검증 범위는 [QA](qa.md)를 따른다.

향후 변경의 검토 방법·완료 조건은 [품질 기준](quality.md), 새로운 OS·SDK 대응은 [호환성 절차](compatibility.md)를 따른다. 아래 표는 현재 구현 결정이며, 다음 OS에서도 같은 모양을 강제하는 영구 규칙이 아니다. 해당 영역의 공식 지침과 실제 앱의 가독성·사용성을 다시 검토한다.

## 근거

- [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos): 창 크기 변경·메뉴·키보드·개인화.
- [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars): 탐색 계층과 시스템 사이드바.
- [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars): 자주 쓰는 명령, 표준 아이콘, 제한된 배경과 색.
- [Materials](https://developer.apple.com/design/human-interface-guidelines/materials): 본문과 탐색·조작 층을 구분하고 Liquid Glass를 절제해 사용.
- [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass), [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views): 표준 컨트롤과 실제 SwiftUI Glass API.
- 사용자가 제공한 [macos-design-skill](https://github.com/ceorkm/macos-design-skill/blob/8f528a2364f996cd42f02a10b1b27198a74ca2a3/SKILL.md) 및 layout/visual/interaction 참조. 확인한 커밋은 `8f528a2364f996cd42f02a10b1b27198a74ca2a3`이다. 이 자료는 제3자 스킬이며 Apple 공식 문서가 아니다. 웹 구현 예시는 SwiftUI 컨트롤로 옮기고, 사용자의 18pt 가독성 요구를 우선했다.

- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility): 플랫폼별 컨트롤 크기, 의미적 색, 가능한 200% 글자 확대.
- 추가 사용자 제공 스킬과 적용 범위·판단은 [추가 디자인 검토](design-review.md)에 기록했다.

## 화면에 적용한 결정

| 영역 | 구현과 이유 |
|---|---|
| 탐색 | `NavigationSplitView` 두 열. `List(.sidebar)`에서 과정과 선택 과정의 목차를 탐색하며 시스템 선택·검색·숨김/표시를 사용한다. |
| 툴바 | Pages 방식으로 `Label(.titleAndIcon)`의 새 과정·읽기 설정·PDF 내보내기·더 보기 이름을 표시한다. 기본 시스템 툴바가 Glass 그룹을 구성한다. SDK 수정 후 툴바 배경 숨김 우회 설정을 제거했고 사이드바 세로 경계를 실제 화면에서 확인했다. |
| 읽기 | 기본 18pt, 14~36pt 조절. 시스템 색과 글꼴, 불투명 본문, 여백 포함 최대 820pt. 본문·그림·표에 Glass를 덮지 않는다. |
| 내용 선택 | 표준 segmented `Picker`, 폭이 부족하면 `ViewThatFits`의 menu Picker. 같은 종류의 내용은 순서를 표시한다. |
| 조작 층 | macOS 26 이상에서 하단 페이지 이동·완료에 `.glass` / `.glassProminent`, 페이지 위치에 `.glassEffect(.regular, in: .capsule)`. `GlassEffectContainer`로 묶고 스크롤 viewport 아래 별도 조작 행에 배치해 본문을 가리지 않는다. |
| 설정·편집 | 읽기 옵션 popover의 Slider/Picker, 과정 초안의 grouped Form/TextField/TextEditor/Stepper, 퀴즈의 TextEditor와 DisclosureGroup. |
| 완료·그림 | 완료 화면도 공통 시스템 버튼 스타일을 사용하고 긴 설명은 왼쪽 정렬·여러 줄로 표시한다. 원본 그림은 이름 있는 버튼으로 기본 이미지 앱에서 확대한다. |
| 키보드 | ⌘N 새 과정, ⌘P PDF, ⌘[ / ⌘] 내용 이동, ⌘+ / ⌘− / ⌘0 크기. OS 예약 단축키를 덮어쓰지 않는다. |
| 저장 | 설정·읽던 위치·메모·선택 정답 공개는 기존 저장 계약을 유지한다. 새 디자인을 위해 교재를 다시 생성하지 않는다. |

Glass API는 macOS 26 SDK 이상으로 빌드하며 `#available(macOS 26.0, *)`로 보호한다. macOS 14~25에서는 표준 bordered 버튼과 bar 재질을 사용한다. 이전 OS 실기기 실행과 접근성의 모든 시스템 조합을 검증한 것은 아니다. 투명도·대비에 관한 시스템 동작은 네이티브 재질에 맡긴다.

SDK 헤더가 최신이어도 실행 파일의 `LC_BUILD_VERSION`이 SDK 14로 기록되면 기본 컨트롤은 이전 디자인을 사용했다. `PackageApp`은 `xcrun`의 실제 SDK를 `-platform_version`에 지정하고 `otool`로 검증한다. 최종 실행 파일은 **minOS 14.0 / SDK 27.0**이다. [Apple의 AppKit 새 디자인 안내](https://developer.apple.com/videos/play/wwdc2025/310/)에 따라 최신 SDK의 기본 툴바·사이드바·표준 컨트롤을 사용한다. 모든 내용에 Glass를 덮는 방식은 사용하지 않는다.

색·모서리·흐림을 직접 모방하는 HTML/CSS 화면을 도입하지 않았다. 창과 컨트롤은 SwiftUI/AppKit이며 WebKit은 기존 로컬 그림 렌더링에만 사용한다. 앞으로 디자인을 바꿀 때도 해당 영역의 현재 Apple 지침을 먼저 확인하고 실제 앱에서 검증한다.
