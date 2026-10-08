# OS·SDK 호환성과 업데이트

확인 날짜: 2026-10-08. 이 문서는 호환성 범위와 변경 절차다. 개별 실행 증거는 [QA 기록](qa.md), 화면 기준은 [디자인](design.md), 반복 검토는 [품질](quality.md)을 따른다.

| 항목 | 현재 상태 |
|---|---|
| 최소 배포 타깃 | macOS 14.0. 선언·빌드 기준이며 모든 OS의 실행 검증을 의미하지 않는다. |
| 로컬 실행 검증 | macOS 27.0.1 / arm64 |
| 로컬 빌드 도구 | Swift 6.4 / macOS SDK 27.0. Xcode 또는 CLT 가능 |
| Swift 언어 모드 | Swift 5. Swift 6 strict concurrency 전환 완료로 표시하지 않는다. |
| CI | macOS 26 / Xcode 26.6 고정 선택. 자동 검사와 로컬 샘플 QA. UI·실제 AI 생성 합격을 뜻하지 않는다. |
| CI Actions | checkout 7.0.1 / upload-artifact 7.0.2, Node 24. 공식 안정 릴리스의 전체 commit SHA를 고정한다. |
| 최신 디자인 API | macOS 26+ Glass availability 분기. 이전 지원 OS는 표준 bordered/bar |
| 미확인 | macOS 14~25 실기기·Intel·접근성 전체 조합·장시간 성능 |

## 업데이트 절차

1. UI/API 수정, OS/SDK·Swift·Codex CLI 업데이트 때 해당 공식 문서를 다시 읽는다. Xcode·macOS release notes와 SwiftUI/AppKit availability·deprecation·동작 변화를 검토하고 날짜·출처·영향 파일을 기록한다. 기억이나 제3자 스킬만으로 최신이라고 판단하지 않는다.
2. 별도 브랜치에서 개발 도구를 명시적으로 선택한다. 안정 버전 배포와 beta/RC 검증을 구분한다. CI의 Xcode 고정 경로·runner 제공 버전·SwiftLint 호환성도 확인한다. 전역 개발 도구 선택은 임의로 변경하지 않는다.
3. `./scripts/check.sh`로 포맷·린트·테스트·패키징을 검증한다. 도구 업데이트의 전체 포맷은 별도 커밋으로 검토한다. 최소 타깃, 컴파일 SDK, Mach-O `LC_BUILD_VERSION`과 실제 실행 OS를 각각 기록한다.
4. 최신 안정 OS와 사용 가능한 최소 지원 OS에서 실제 앱을 실행한다. availability 분기만 컴파일한 경우 구형 OS 실행 검증으로 보고하지 않는다. 불가한 환경은 미검증으로 남기며 지원 범위 변경은 제품 결정으로 별도 합의한다.
5. 탐색·툴바·검색·설정·sheet·본문 크기·테마·접근성·저장 재개·생성 취소·그림·PDF·스크롤 성능을 변경 범위에 맞게 확인한다. API 컴파일 성공만으로 새 디자인·동작이 적용됐다고 판정하지 않는다.
6. 검증 결과와 새 캡처를 기록한다. 실패 시 사용자 보관함·설정·인증 파일을 보존하고 직전 정상 바이너리로 비교한다. 데이터 포맷 변경은 버전·복구 가능한 이전·회귀 테스트가 준비돼야 한다.

기본 시스템 컴포넌트를 유지하고 사용자 지정 배경·색·모서리·픽셀 보정을 최소화해 다음 OS 디자인도 시스템이 반영하도록 한다. 새로운 디자인 명칭을 영구 규칙으로 고정하지 않고 그 시점의 공식 원칙과 가독성으로 판단한다.

## Swift 6 전환

현재는 기존 동작을 보존한 구조 분리가 우선이다. 이후 별도 변경에서 concurrency 진단을 수집하고 공유 가변 상태·Sendable·actor 격리·취소를 검토한다. 경고 제거를 위한 blanket `@unchecked Sendable`, `nonisolated(unsafe)`나 진단 비활성화는 허용하지 않는다. 프로세스 레지스트리·WebKit callback·원자적 저장의 계약을 테스트한 뒤 언어 모드를 전환한다. `await`가 있다는 이유로 무거운 작업이 메인 액터 밖에서 실행된다고 가정하지 않는다.

## 공식 출처

- [Apple Xcode release notes](https://developer.apple.com/documentation/xcode-release-notes)
- [Apple macOS release notes](https://developer.apple.com/documentation/macos-release-notes)
- [Apple Liquid Glass 적용](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
- [Apple SwiftUI 성능](https://developer.apple.com/videos/play/wwdc2025/306/)
- [Swift migration guide](https://www.swift.org/migration/documentation/migrationguide/)
- [GitHub macOS runner 이미지](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md)
- [checkout 7.0.1 릴리스](https://github.com/actions/checkout/releases/tag/v7.0.1), [upload-artifact 7.0.2 릴리스](https://github.com/actions/upload-artifact/releases/tag/v7.0.2): 2026-10-08 확인. Node 20 폐기 경고에 대응해 Node 24 릴리스로 변경했다. 실제 실행 결과는 해당 revision의 Quality 실행으로 확인한다.
