# 개발 안내

Swift Package Manager로 빌드하는 Swift 전용 macOS 앱입니다. SwiftUI와 AppKit으로 화면을 구성하고, Foundation 모델과 원자적 JSON 저장을 사용합니다. 구현 구조와 데이터 계약은 [상세설계](lld.md)를 따릅니다.

그림은 앱 안의 로컬 WebKit으로 렌더링하며, PDF는 AppKit, CoreText와 CoreGraphics로 생성합니다. Python 백엔드나 별도 HTTP 서버는 없습니다. 패키징 도구는 리소스를 포함하는 `.app`을 만들고 실행 파일의 SDK와 최소 OS 기록을 검증합니다.

## 공통 검사

```sh
./scripts/format.sh
./scripts/check.sh
```

`format.sh`는 소스를 포맷합니다. `check.sh`는 포맷과 SwiftLint, 구조 검사, 문서 링크, 스크린샷 기록, 테스트와 Release 패키징을 확인합니다. 첫 실행에서 공식 SwiftLint 배포의 SHA-256을 확인하고 `.tools/`에 받습니다. 상세 규칙과 실제 화면의 완료 조건은 [품질 기준](quality.md)에 있습니다.

GitHub Actions도 같은 명령과 고정 샘플 QA를 실행합니다. 자동 검사에는 실제 AI 호출이 포함되지 않으며, 합격만으로 학습 내용의 정확성이나 화면 품질, 체감 성능을 보증하지 않습니다.

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
- [제품 요구사항](requirements.md)
- [상세설계](lld.md)
- [품질 기준](quality.md)
- [OS와 SDK 호환성](compatibility.md)
- [유지보수 구조 결정](decisions/001-maintenance.md)
- [macOS 디자인 기준](design.md)
- [디자인 스킬 검토](design-review.md)
