# 개발·검증 도구 구성

| 도구 | 계획한 역할 | 상태 |
| --- | --- | --- |
| VS Code | 코드 및 문서 작성, 에이전트 작업, 터미널 | 설치 확인 이력 있음 |
| Xcode | 프로젝트 생성, SDK, 빌드, 시뮬레이터, 추후 서명 | 설치 확인 이력 있음 |
| Swift 공식 확장 / SweetPad | 편집 지원과 VS Code 내 빌드·실행 보조 | 공유 대화의 후보, 설치 미확인 |
| xcodebuild | 앱 빌드와 테스트 | 프로젝트 생성 후 검증 |
| simctl | 시뮬레이터 목록·실행·앱 설치 | `scripts/run-simulator.sh`에서 사용 |
| devicectl | 실제 아이폰 관리 | 기기 확보 후 사용 |

## 자동화 구성

- `scripts/build-ios.sh`: 프로젝트·스킴과 선택한 시뮬레이터 대상으로 빌드.
- `scripts/test-ios.sh`: 단위/UI 테스트를 실행하고 실패 종료 코드를 전달.
- `scripts/run-simulator.sh`: 선택한 시뮬레이터 시작, 빌드된 앱 설치 및 실행.
- `.vscode/tasks.json`: 위 작업의 Build·Test·Run Simulator 항목을 제공.

기기 이름이나 개인 장치 ID를 무조건 고정하지 않습니다. 프로젝트 루트 경로에 공백이 있으므로 스크립트 경로 인자를 인용합니다. 도구 경로, 런타임 또는 프로젝트가 없으면 원인을 안내하도록 합니다.

기본 시뮬레이터는 iPhone 17 Pro입니다. `IOS_SIMULATOR_NAME` 또는 `IOS_SIMULATOR_UDID`로 대상을 변경하고, `IOS_DERIVED_DATA_PATH`, `IOS_SCHEME`, `IOS_CONFIGURATION`으로 빌드 값을 조정할 수 있습니다. 실제 폰 준비 전에는 시뮬레이터 작업을 기본으로 하고 Personal Team 및 기기 서명은 후속 절차로 둡니다.

## 환경 확인 이력


다음은 2026-09-08에 확인한 값이며 이번 문서 작업에서 다시 점검한 결과는 아닙니다.

| 항목 | 마지막 확인 |
| --- | --- |
| Mac | arm64, macOS 26.6.2 |
| VS Code | 1.136.1, code 명령 연결됨 |
| Git | 2.50.1 |
| Xcode | 26.6, 초기 라이선스 및 준비 검사 통과 |
| iOS SDK / 시뮬레이터 런타임 | 26.5 설치됨 |
| 시뮬레이터 | iPhone 17 Pro 등 등록, 당시 종료 상태 |
| 기본 개발 도구 경로 | Command Line Tools — 구현 시작 전 재확인 필요 |
| 실제 아이폰 | 2026-09-26 연결·페어링 확인: iPhone 16 Pro Max, iOS 26.6.2. 개발자 모드 비활성 |

Swift/SweetPad 확장 설치 상태는 미확인입니다. 빌드와 앱 실행은 수행하지 않았습니다.

## 2026-09-09 재확인

Xcode 26.6과 iOS 26.5 시뮬레이터를 확인했습니다. iPhone 17 Pro 부팅 명령과 bootstatus가 성공했고 스크린샷으로 홈 화면을 확인했습니다. 앱 빌드는 아직 수행하지 않았습니다.

기본 경로는 여전히 `/Library/Developer/CommandLineTools`입니다. `sudo -n xcode-select --switch /Applications/Xcode.app/Contents/Developer`는 관리자 암호 필요로 실패하여 전역 설정은 바뀌지 않았습니다. 현재 검증에는 명령별 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`를 사용했습니다.

사용자가 터미널에서 다음 명령을 실행하면 기본 경로 전환을 마칠 수 있습니다.

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
xcode-select -p
```

## 기본 프로젝트 실행 — 2026-09-09

사용자가 경로 전환을 실행한 뒤 `xcode-select -p`가 `/Applications/Xcode.app/Contents/Developer`를 반환하고 `xcodebuild -version`이 정상 실행됨을 확인했습니다. 위 관리자 암호로 인한 미완료 기록은 과거 이력입니다.

XcodeGen 2.46.0을 Homebrew로 설치했습니다. 프로젝트 정의 변경 후 루트에서 `xcodegen generate`를 실행합니다. 생성된 xcodeproj는 그대로 Xcode에서 열 수 있습니다.

검증에 사용한 명령:

```sh
xcodebuild -project PictureFilterApp.xcodeproj -scheme PictureFilterApp \
  -destination 'platform=iOS Simulator,id=9533B106-C319-4D9A-8527-0AB609143CCB' \
  -derivedDataPath /tmp/PictureFilterApp-DerivedData \
  -parallel-testing-enabled NO test
```

위 ID는 이 맥에서 확인한 대상입니다. 다른 환경은 `xcrun simctl list devices available`로 대상 ID를 확인해 교체합니다. 실제 폰 서명 팀은 아직 지정하지 않았습니다.

## 2026-09-26 자동화 및 UI 검증

Xcode 26.6 / iOS 26.5 시뮬레이터에서 `scripts/build-ios.sh`, `scripts/test-ios.sh`, `scripts/run-simulator.sh`를 실행했습니다. 전체 테스트는 iPhone 17 Pro에서 통과했습니다. 앱 실행 스크립트도 설치 후 `com.local.PictureFilterApp` 실행 PID를 반환했습니다.

VS Code 작업 파일은 JSON 파싱 검사를 통과했습니다. 셸 스크립트는 `bash -n` 검사를 통과했습니다. 프로젝트 루트의 공백 경로를 포함해 동작을 확인했습니다.

작은 화면 검증용 iPhone 17e는 첫 부팅 데이터 마이그레이션을 마쳤습니다. 샘플 화면 이동과 가장 큰 Dynamic Type 편집 UI 검사를 선택 실행해 2개 모두 통과했습니다. Photos 권한·저장 UI를 포함한 전체 스위트는 17e에서 완료되지 않았으며, 저장 흐름은 iPhone 17 Pro 전체 스위트에서 통과했습니다. 테스트 스크립트는 선택된 XCTest 필터 옵션을 추가 인자로 전달할 수 있습니다.

## 실제 아이폰 연결 점검 — 2026-09-26

- Mac: macOS 27.0, arm64e. Xcode 26.6, 기본 개발 도구 경로 `/Applications/Xcode.app/Contents/Developer`.
- 연결 기기: iPhone 16 Pro Max (모델 iPhone17,2), iOS 26.6.2 (23G90), USB 연결.
- 페어링: available (paired), 유선 터널 연결. `xcodebuild -showdestinations`에 `정부장폰` iOS 대상으로 표시.
- 개발자 모드: 2026-09-26 재부팅 후 **활성화** 확인. DDI 서비스 사용 가능, USB 터널 연결 정상, 재부팅 이후 잠금 해제 상태 확인.
- 점검은 읽기 전용으로 수행했습니다. 폰 설정이나 앱 설치는 변경하지 않았습니다.

다음은 아이폰에서 설정 → 개인정보 보호 및 보안 → 개발자 모드를 켜고 재시동한 뒤 확인을 완료하는 단계입니다. 개발자 모드는 개발용 실행과 디버깅을 허용하므로 사용자가 폰에서 직접 활성화합니다. 이후 케이블을 유지한 채 다시 연결 확인 후 앱 서명과 실행을 진행합니다. 앞의 미감지 기록은 2026-09-08 당시 상태이며 현재는 연결된 상태입니다.


재부팅 후 재점검: `devicectl`에 developerModeStatus enabled 및 DDI 서비스 사용 가능이 표시되고, 잠금 상태는 unlockedSinceBoot입니다. `xcodebuild -showdestinations`에서 실제 기기를 다시 확인했습니다. 기기용 빌드는 `CODE_SIGNING_ALLOWED=NO`로 성공했습니다. 이는 컴파일만 확인한 결과이며 서명·설치·실행은 검증하지 않았습니다.

현재 타깃의 DEVELOPMENT_TEAM 값은 비어 있습니다. 실제 기기에 설치하려면 Xcode Signing & Capabilities에서 Apple 계정의 개발 팀을 선택하고, 필요하면 Bundle Identifier를 해당 팀에서 사용할 수 있는 고유 값으로 바꾼 뒤 자동 서명을 구성해야 합니다. 계정 정보나 코드 서명 설정은 이번 점검에서 변경하지 않았습니다.


## PF-017 서명 점검 — 2026-09-26

연결된 기기를 대상으로 기본 서명 빌드를 시도했으나 `Signing for "PictureFilterApp" requires a development team` 오류로 중단됐습니다. 현재 프로젝트의 DEVELOPMENT_TEAM이 설정되지 않았고 Bundle Identifier는 `com.local.PictureFilterApp`입니다. 서명 없는 기기 빌드는 성공했으므로 SDK·컴파일·대상 연결은 준비되어 있습니다.

실기기 설치 전 사용자가 Xcode Signing & Capabilities에서 Apple 계정의 팀을 선택해야 합니다. 팀이 허용하는 고유 Bundle Identifier도 정해야 합니다. 개인 테스트에는 Xcode에 등록된 Personal Team을 사용할 수 있지만 이 맥에 등록되어 있는지는 아직 확인하지 않았습니다. 계정 로그인·팀 선택·서명 설정을 변경하지 않았습니다.


## 인증서 확인 — 2026-09-26

읽기 전용 키체인 점검 결과 Apple Development 인증서 1개가 보이고 만료일은 2027-09-26입니다. `security find-identity -v -p codesigning` 결과는 0 valid identities입니다. 즉, 현재 로그인 키체인 검색 범위에 Xcode 코드 서명에 사용할 개인 키와 인증서의 쌍이 없습니다. 로컬 provisioning profile도 0개입니다. Xcode 프로젝트 `DEVELOPMENT_TEAM`은 공란이고 앱 Bundle Identifier는 `com.local.PictureFilterApp`입니다.

Xcode → Settings → Accounts에서 개인 팀의 Manage Certificates를 열어 해당 인증서가 이 Mac에 개인 키와 함께 있는지 확인해야 합니다. 인증서만 있고 개인 키가 없다면, 인증서를 만든 Mac의 개인 키를 포함한 `.p12`를 가져오거나 Xcode에서 Apple Development 인증서를 새로 생성해야 합니다. 그 뒤 프로젝트 Signing & Capabilities에서 개인 팀과 사용 가능한 고유 Bundle Identifier를 선택해 자동 서명을 확인합니다. 이번 점검은 키체인·프로젝트·프로파일을 변경하지 않았습니다.


## 2026-09-30 · 훅 실패와 작업 경로 점검

- 실제 작업·빌드·Git 저장소: `/Users/jsjmac/Workspace/MacWorking/PictureFilterApp`. Codex 앱의 등록된 `picfilterapp` 프로젝트도 이 내장 경로입니다.
- 이 오래된 대화의 세션 작업 경로에는 `/Volumes/Crucial X6/MacWorking/PictureFilterApp`가 남아 있으며 현재 해당 폴더는 존재하지 않습니다. 앱 로그의 workspace watcher에도 같은 경로의 `ENOENT`가 반복 기록됩니다.
- 활성 Git 훅은 없습니다. `core.hooksPath`는 지정되지 않았고 `.git/hooks`에는 `.sample`만 있습니다. Xcode 프로젝트·VS Code 작업·빌드 스크립트에도 외장 경로 하드코딩은 없습니다.
- Codex 사용자 훅 설정 `/Users/jsjmac/.codex/hooks.json`에는 Serena의 `SessionStart`, `PreToolUse`, `Stop` 명령이 등록되어 있습니다. 실행 파일과 Python 환경은 존재합니다. 동일한 점검용 입력을 내장 경로에서 실행한 `serena-hooks remind --client=codex`는 종료 코드 0, 표준 오류 없음으로 정상 종료했습니다. 외장 경로를 프로세스 작업 디렉터리로 지정하면 `FileNotFoundError(2)`가 재현됩니다.
- [공식 훅 문서](https://learn.chatgpt.com/docs/hooks)에 따르면 명령 훅은 세션 cwd에서 실행됩니다. 따라서 현재 세션의 사라진 cwd가 훅 실행을 방해할 수 있음이 재현됐습니다. 앱 로그에서 개별 훅의 전체 stderr를 얻은 것은 아니므로 모든 과거 훅 오류가 동일 원인이라고 단정하지 않습니다.
- **남은 조치:** 이 대화를 내장 경로로 재개해야 합니다. 프로젝트 등록 변경과 개별 대화의 cwd는 별개입니다. 현재 제공된 앱 도구에는 실행 중인 이 대화의 cwd 변경 기능이 없으며, 다른 대화 이동 도구도 호출 중인 대화 자체를 이동할 수 없습니다. 사용자가 내장 `picfilterapp` 프로젝트에서 작업을 다시 열거나 그 경로에서 이어갈 때 훅 실행을 재확인해야 합니다. 실제 작업 파일과 커밋은 이미 내장 저장소에 있습니다.
- 전역 Serena 훅은 다른 프로젝트에도 영향을 주므로 이번 점검에서 제거·무력화하지 않았습니다. 존재하지 않는 외장 마운트 경로를 흉내 내는 링크나 앱 내부 DB 직접 수정도 하지 않았습니다. 새 경로에서 실패가 계속되면 훅 오류의 실제 stderr를 확인하여 별도 원인으로 분리합니다.
