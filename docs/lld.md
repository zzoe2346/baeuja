# 상세설계

제품 계약은 [요구사항](requirements.md), 협업 규칙은 [AGENTS.md](../AGENTS.md)를 따른다.

## 구성

`StudySwift`는 SwiftUI 화면과 메인 액터의 `StudyStore`를 소유한다. `StudyCore`는 Codable 모델·검증, 원자적 보관함, Codex CLI, 시각자료와 PDF를 제공한다. `PackageApp`은 Swift 빌드 결과를 `.app`으로 묶는다. `RunTests`는 Swift Testing의 도구 환경을 준비하고, `StudyQA`는 격리된 로컬/실제 구독 QA를 실행한다. Python·별도 HTTP 서버·외부 패키지 의존성은 없다.

```text
SwiftUI / AppKit
       |
  StudyStore
       +-- LibraryRepository --> library.json / materials
       +-- CodexClient --> CLI child --> remote Codex service
       +-- VisualRenderer --> local WebKit / native PNG / ASCII
       +-- PDFExporter --> CoreText / CoreGraphics --> part.pdf
```

## 데이터와 저장

- `Plan`과 `Lesson`은 기존 버전 1 JSON 필드명을 유지한다. Codable snake_case 변환과 추가 의미 검증을 사용한다.
- 과정 상태는 draft/active/complete다. 계획은 시작 이후 고정한다. 파트 완료는 명시적인 다음 선택으로만 설정한다. 미완료 파트를 먼저 찾아 이동한다.
- `LibraryState`는 과정·파트별 `PartProgress`, 검증된 `LessonRecord`, 선택 과정을 저장한다. 진도에는 현재 내용·스크롤 오프셋·퀴즈 메모·공개 ID가 있다.
- 기본 폴더는 `~/Library/Application Support/StudySwift`다. `--data-dir`로 QA/데모를 격리한다. 자료와 생성 작업은 각각 `materials/<UUID>`, `jobs/<UUID>`다.
- 변경은 사본을 만들고 원자적 쓰기가 성공한 뒤 UI 상태로 채택한다. 읽을 수 없는 기존 보관함은 덮어쓰지 않고 저장을 중지한다. 자료 폴더 준비 실패도 오류 화면을 표시하고 저장·AI 생성을 중지한다.
- 교재 재생성은 새 자료 폴더에서 검증·렌더링이 모두 끝난 뒤 참조를 교체한다. 실패·취소 시 이전 자료·진도를 유지한다.
- 자산 경로는 보관함 내부인지 확인한다. 생성 파일의 심볼릭 링크·크기·PNG 디코딩/픽셀 수를 검사한다.

## CLI 계약

`login status`에서 ChatGPT 인증을 먼저 확인한다. 환경에서 API 키 두 변수를 제거하고 인증 파일은 기존 위치를 그대로 사용한다. 생성은 `exec --ignore-user-config --ephemeral --skip-git-repo-check --json --output-schema --output-last-message`이며 작업 디렉터리는 전용 job 폴더다. forced_login_method=chatgpt, 검색 cached/live, 앱·브라우저·컴퓨터 사용은 비활성화한다. 모델은 지정하지 않는다.

POSIX spawn의 독립 프로세스 그룹과 stdin/stdout/stderr 파이프를 사용한다. 이벤트·총 출력·최종 파일 크기를 제한하고 완료 이벤트와 종료 코드, 실패 이벤트를 확인한다. 취소/시간 제한/종료 시 그룹을 정리한다. 제한 시간 기본값은 계획 180초, 교재 600초, 삽화 240초다. 자동 재시도는 없다.

삽화는 CLI의 네이티브 이미지 기능을 한 번 사용하고 작업 폴더의 실제 `image.png`만 수집한다. 미지원·실패 시 교재에 이미 저장된 후보로 이동한다. 새 AI 대체 호출·유료 API 전환은 없다.

## 시각자료와 PDF

필수 그림마다 원본, 저장 후보 순으로 처리한다. ASCII는 인쇄 가능한 ASCII/LF만, 탭 없이 최대72열이다. SVG는 XML 파서로 요소·이벤트·외부 참조·DOCTYPE/ENTITY를 거부한다. Mermaid는 로컬 번들을 strict 모드로 실행하고 생성 SVG도 검사한다. WebKit 결과는 PNG로 고정해 화면과 PDF가 같은 선택 자산을 사용한다. 렌더링 제한 시간은 30초다.

UI는 SwiftUI 텍스트·코드·표·목록·메모·시각자료를 사용한다. 과정 초안은 제목·목표·범위와 파트별 제목·시간·목표를 네이티브 입력으로 편집하며 파트를 추가/삭제할 수 있다. 본문은 실제 viewport 폭으로 NSHostingView의 높이를 계산하고 NSScrollView의 내용별 오프셋을 저장·복원한다. 동일 종류의 내용이 여러 개면 탭 이름에 순서를 표시한다. Markdown 원시 HTML을 실행하거나 원격 이미지를 다운로드하지 않는다. 기본 본문 18pt, 범위 14~28pt, 밝은 테마, 내용 폭 최대900pt다.

PDF는 A4, 시스템 한글 글꼴과 고정폭 코드/ASCII, CoreText 줄바꿈·페이지 나눔을 사용한다. 문제를 새 페이지에서 시작하고 정답은 문제 이후의 새 페이지에서 시작한다. 생성 후 PDFKit으로 문서를 다시 열고 유효성을 확인한 뒤 출력 파일을 원자적으로 교체한다.

실제 실행·실패 fixture·페이지 검토 결과와 남은 한계는 [QA 기록](qa.md)에 구분해 기록한다.

## 도구 환경

macOS 27 SDK의 SwiftUI `State` 매크로는 Xcode 전용 플러그인을 요구한다. 지역 타입 별칭을 통해 기존 property wrapper를 사용해 Command Line Tools로도 빌드한다. `RunTests`는 활성 `swiftc`의 도구 폴더에서 Testing 매크로 라이브러리를 찾아 필요할 때 명시적으로 로드한다. 테스트 프레임워크는 Swift Testing이다.

앱 패키징은 SwiftPM의 `--show-bin-path` 결과를 사용해 실행 파일과 모든 리소스 번들을 복사하고 ad-hoc 서명한다. 현재 구현의 macOS 최소 타깃은14이며 실제 실행 환경과 확인하지 않은 범위는 QA 기록에 적는다.
