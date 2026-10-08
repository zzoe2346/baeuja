# 002: 배우자 이름과 기존 데이터 호환

상태: 승인, 적용. 날짜: 2026-10-08. 사용자가 앱 이름 **배우자 (Let’s Learn)**와 GitHub 레포명 **baeuja**를 승인했다. [001의 기존 이름 유지](001-maintenance.md) 결정 중 제품 이름과 UI 타깃 이름을 대체한다.

## 결정

- 사용자에게 표시하는 이름은 한국어 배우자, 영어 Let’s Learn이다. README 제목은 배우자 — Let’s Learn으로 표시한다.
- GitHub 저장소와 로컬 체크아웃 폴더는 `baeuja`, SPM 패키지와 앱 실행 타깃은 `Baeuja`, 배포 번들은 `배우자.app`이다. 사용 안내 링크, clone, 실행, 검사 명령을 함께 갱신한다.
- `AppResources`의 언어별 `InfoPlist.strings`를 번들에 포함하고 시스템이 고른 `CFBundleDisplayName`을 창 제목과 빈 보관함 제목에 사용한다. 아이콘 원본과 후보는 그대로 유지한다.
- `com.zzoe.study-swift` bundle identifier와 `~/Library/Application Support/StudySwift` 저장 경로는 유지한다. 앱 표시 이름과 내부 호환성 식별자를 구분해 기존 사용자 설정, 교재, 메모와 읽던 위치를 바로 읽는다. 원본 사용자 자료를 이동하거나 새 보관함으로 복사하지 않는다.
- 과거 QA의 당시 제품 상태와 revision 기록은 보존한다. GitHub URL은 새 저장소 주소로 갱신한다.

## 근거와 검증

2026-10-08에 Apple의 [표시 이름](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundledisplayname), [짧은 이름](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundlename), [Info.plist 지역화](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/AboutInformationPropertyListFiles.html)를 확인했다. 표시 이름 두 키를 언어별로 포함하며 파일 시스템의 번들 이름도 기본 표시 이름과 맞춘다. 상세 검증 결과는 [QA 기록](../qa.md)에 남긴다.

교재 생성, 저장 형식과 화면 구조를 변경하지 않는다. 향후 bundle identifier나 저장 폴더를 변경하려면 충돌, 이전 실패와 재실행을 다룬 별도 이전 설계가 필요하다.
