# 추가 SwiftUI 디자인 검토

2026-10-08. 사용자가 제공한 자료를 읽고 현재 macOS 앱의 코드와 실제 실행 화면을 대조했다. Apple HIG와 제품의 읽기 요구를 우선하며, 제3자 스킬의 취향이나 iOS 규칙을 macOS 요구사항으로 간주하지 않는다.

## 확인한 자료와 적용 범위

- [SwiftUI Native Design 27](https://github.com/RichardZhengQuan/swiftui-native-design-skill/blob/3b44c1105b74cb391dcf196a0806e446b6bc2b87/.agents/skills/swiftui-native-design-27/SKILL.md): 네이티브 구조, 작업 흐름, 컴포넌트 선택, 실기기 검증 기준과 네 개 참조 문서를 읽었다. 현재 macOS 27 SDK 환경에 맞는 버전을 진단에 사용했다. 시스템 컴포넌트의 실제 동작과 확인 가능한 증거를 검수 기준으로 삼는다.
- [SwiftUI Design Skill](https://github.com/Wholiver/swiftui-design-skill/blob/2c82638ebd3c801d9d2d12b5f2d6c20495939995/SKILL.md): 디자인 방향·계층·완성도·사용성·제품 맥락의 검토 틀과 anti-ai-slop/typography 참조를 읽었다. 반복 카드, 장식, 임의 여백을 줄이는 데 참고한다. 세리프 제목·따뜻한 브랜드색·44pt 터치 영역은 일괄 적용하지 않는다. 시스템 색·글꼴·macOS 컨트롤 크기와 사용자가 요청한 큰 본문을 유지한다.
- [OpenClaw 네이티브 교체 제안](https://github.com/openclaw/openclaw/issues/99195): 커스텀 UI 층을 줄이는 사례로 참고했다. 이슈에 제안과 프로토타입 검증이 있다는 사실을 메인 코드 반영의 증거로 사용하지 않는다.
- [한 화면부터 리디자인한 경험](https://www.reddit.com/r/ClaudeAI/comments/1mchugi/how_i_used_ai_to_completely_overhaul_my_apps_uiux/)과 [수치를 전달한 경험](https://www.reddit.com/r/ClaudeAI/comments/1ouc6bu/tip_for_ui_design_with_claude/): 구체적 기준과 실제 결과를 대조하는 작업 방식에 참고했다.
- [awesome-ios-design-md](https://github.com/Meliwat/awesome-ios-design-md): 명세의 분류 방식은 참고하되 개별 모바일 앱의 브랜드와 레이아웃을 이 데스크톱 학습 도구에 복제하지 않는다.

전역 스킬 설치나 Xcode 설정 변경은 하지 않았다. 자료는 설계 검토에 사용했으며 스킬 원문·UI kit 자산을 저장소에 복사하지 않았다.

## 비교한 방향

| 방향 | 이 앱에서의 의미 | 판단 |
|---|---|---|
| 네이티브 학습 도구 | 시스템 탐색·명령·입력, 큰 본문, 그림과 퀴즈 중심 | 기존 사용자 요청과 일치해 유지 |
| 읽기에 집중한 문서 화면 | 목차를 숨기고 본문에 더 많은 공간 제공 | 기존 사이드바 숨김과 본문 폭 제한으로 지원 |
| 학습 작업 공간 | 자료 옆 별도 메모·참고 inspector | 새로운 작업 흐름이므로 이번 개선에 추가하지 않음 |

## 발견과 수정

| 문제 | 코드의 원인 | 반영 |
|---|---|---|
| 충분한 글자 확대 | 기본 18pt, 상한 28pt | `ReaderTypography`로 기본·범위를 공유하고 상한 36pt로 확대. Apple HIG의 가능한 200% 확대 권고에 맞춤 |
| 큰 글자와 하단 버튼 겹침 | ReaderView의 스크롤 위 footer overlay | footer를 viewport 아래 독립 행으로 이동. 실제 Glass 버튼 사용 유지 |
| ASCII·코드 열 정렬 붕괴 | 일반 본문처럼 폭에 맞춰 자동 줄바꿈 | `MonospacedBlock`에서 원래 줄·공백 유지, 가로 스크롤 제공 |
| 스크롤 중 반복 저장·레이아웃 | offset 이벤트마다 전체 library publish/save | 최신 위치를 메모리에 모으고 350ms idle 후 저장. 이동·비활성화·종료 때 즉시 반영 |
| 최신·이전 디자인 혼합 | 실행 파일 링크 SDK가 14.0으로 기록됨 | 실제 SDK를 지정해 링크하고 검증. 기본 사이드바·검색·그룹 툴바에 새 디자인 적용. 툴바 배경 숨김 우회 제거 |
| 심화 설명 잘림 | 시스템 버튼의 기본 한 줄 제한 | 명시적 여러 줄 표시·왼쪽 정렬 적용 |

## 상단 명령 비교와 선택

사용자는 **A · Pages처럼 기능 이름 표시**를 선택했다. [Pages의 툴바 사용자화](https://support.apple.com/guide/pages/customize-the-toolbar-tanafa2f718a/15.4/mac/1.0)는 아이콘·텍스트 표시를 지원한다. [Preview 안내](https://support.apple.com/en-nz/guide/preview/prvw11470/mac)의 읽기·크기 도구 중심 방식과 [Obsidian 명령 검색](https://help.obsidian.md/plugins/command-palette)의 키보드 검색 방식을 함께 비교했다. 현재 기능 수와 선택한 방향에 맞춰 자주 쓰는 명령 이름을 화면에 표시한다.

`새 과정`, `읽기 설정`, `PDF 내보내기`를 기본 시스템 툴바에 배치하고 `더 보기`에는 가져오기·재생성·원본 그림 재시도를 둔다. [Apple Toolbars HIG](https://developer.apple.com/design/human-interface-guidelines/toolbars)에 따라 File·View·학습 메뉴도 제공한다. 861pt 창에서 명령 이름은 유지되고 긴 과정 제목만 시스템 방식으로 축약된다.

SDK 수정 뒤 기본 시스템 컨트롤과 공통 `StudyActionStyle`을 기준으로 창·검색·툴바·내용 선택·설정·계획·새 과정·퀴즈·완료 화면을 검토했다. 내용 층에는 읽기용 시스템 배경을 유지하고 조작 층에 네이티브 Glass를 사용한다. 실행 증거는 QA 기록에 구분했다.

## 화면별 검수 기준

본문·그림·퀴즈를 읽고 현재 파트를 완료하는 것이 주 작업이다. 설정·PDF·재생성은 보조 명령이다. 각 화면에서 현재 선택과 다음 동작이 보이는지, 작은 창과 큰 글자에서 내용이 잘리거나 겹치지 않는지, 키보드·이름 있는 컨트롤로 같은 작업에 도달하는지 확인한다. 생성 중에는 활동과 취소, 실패 뒤에는 기존 자료와 재시도 경로가 남아야 한다.

가독성은 본문·캡션·Glass 조작 영역을 각각 검토한다. 정렬은 창 경계·본문·표·도식·코드에서 확인한다. 생성 결과는 고정 샘플과 구분하고, 실제 교재와 그림에서 검사한다. 컴파일 성공이나 주관적 점수를 디자인 완료의 증거로 삼지 않는다. 실행 증거와 확인하지 않은 접근성·OS 조합은 [QA 기록](qa.md)에 남긴다.
