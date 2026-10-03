# 검증 계획

열린 검증 작업은 [TASKS](TASKS.md)의 PF-018~PF-019에서 관리하고, 완료된 작업의 상태와 전체 이력은 [TASKS_ARCHIVE](TASKS_ARCHIVE.md)에서 확인합니다. 이 문서는 검증 기준과 실행 증거를 기록합니다. 문서 링크 검사는 앱 검증에 포함하지 않습니다.

## 폰 없이 수행할 검증 — 구현 후

- 시뮬레이터에 앱 설치 및 시작 화면 표시.
- 샘플 이미지로 편집 화면 진입, 방향·비율 유지.
- 필터 변경, 강도 끝값, 원본 비교와 초기화.
- 필터 반복 적용 시 누적되지 않음.
- 빠른 조작이나 사진 변경 후 마지막 요청만 반영.
- 출력 파일을 다시 읽어 방향, 크기, 효과 확인.
- 입력 실패·저장 실패·권한 거부 대역에서 재시도 동작.
- 작은 화면과 큰 글자에서 버튼 접근 가능.
- 시뮬레이터 사진 선택 및 저장 흐름 확인.

핵심 자동 테스트 후보: 강도 0에서 원본 보존, 초기화 상태, 필터 비누적, 오래된 처리 결과 배제, 출력 이미지 디코딩. UI 테스트는 샘플 선택 → 편집 → 결과 확인의 한 흐름을 우선합니다.

## 실제 아이폰에서 수행할 검증

- 기기 신뢰, 개발자 모드, 서명, 설치와 실행.
- 실제 사진 보관함 접근 허용·거부·설정 변경 후 복구.
- iCloud 사진 로딩 및 네트워크 실패.
- 결과 사진 저장과 원본 유지, 실제 화면의 색감·방향 비교.
- 고해상도 사진 반복 처리, 메모리·발열·속도.
- 카메라·얼굴 인식을 채택하면 전후면·회전·저조도 검증.

시뮬레이터의 속도, 메모리, 카메라 및 권한 대역 결과를 실기기 검증으로 대체하지 않습니다.

## 결과 기록 양식

| 날짜 / 작업 ID | 앱 버전/커밋 | 환경 | 항목 | 결과 | 재현 및 제약 |
| --- | --- | --- | --- | --- | --- |


## PF-004 실행 증거 — 2026-09-09

- 환경: Xcode 26.6, iPhone 17 Pro 시뮬레이터, iOS 26.5.
- xcodebuild test: TEST SUCCEEDED, 테스트 2개 통과, 실패 0.
- AppHostTests: 앱 타깃이 테스트 호스트로 로드되는지 확인.
- LaunchTests: 앱 실행 후 시작 화면 제목과 내비게이션 바 확인.
- simctl launch 재실행 성공, 시작 화면 이미지 확인.
- 빌드 로그: `/tmp/PictureFilterApp-build.log`.
- 결과 번들: `/tmp/PictureFilterApp-DerivedData/Logs/Test/Test-PictureFilterApp-2026.09.09_21-43-35-+0900.xcresult`.
- 화면 캡처: `/tmp/PictureFilterApp-welcome.png`.

임시 경로의 증거 파일은 시스템 정리 시 없어질 수 있습니다. 이번 검증은 프로젝트 구성과 기본 실행 범위이며 사진 편집·저장 기능 검증은 아닙니다.

## PF-005 실행 증거 — 2026-09-09

Xcode 26.6 / iPhone 17 Pro / iOS 26.5에서 xcodebuild test 성공. 단위 테스트 7개와 UI 테스트 1개, 총 8개 통과 및 실패 0개.

새 서비스 테스트 6개는 번들 샘플 2개의 크기·방향·디코딩, 저장 데이터 왕복·서로 다른 ID·메모리 비우기, 미등록 샘플, 입력 실패 주입, 저장 거부/실패 시 미저장, 잘못된 이미지 거부를 검증합니다. 기존 앱 호스트 및 시작 화면 테스트도 통과했습니다.

- 로그: `/tmp/PictureFilterApp-PF005.log`.
- 결과: `/tmp/PictureFilterApp-DerivedData/Logs/Test/Test-PictureFilterApp-2026.09.09_21-47-05-+0900.xcresult`.

실제 사진 권한이나 보관함 저장을 검증한 결과는 아닙니다. 화면 연결 및 필터 처리는 후속 작업입니다.

## PF-006 실행 증거 — 2026-09-10

Xcode 26.6, iPhone 17 Pro / iOS 26.5에서 TEST SUCCEEDED. 단위 7개와 UI 2개, 총 9개 통과 및 실패 0개.

UI 테스트는 시작 화면 표시와 가로 샘플 진입 → 세로 샘플 변경 → 시작 화면 복귀 → 세로 샘플 재진입을 검증했습니다. 첨부 화면에서 세로 사진 비율, 사진 변경 메뉴, 필터·강도·버튼 영역과 준비 중 안내를 확인했습니다.

- 로그: `/tmp/PictureFilterApp-PF006.log`.
- 결과: `/tmp/PictureFilterApp-DerivedData/Logs/Test/Test-PictureFilterApp-2026.09.10_22-02-34-+0900.xcresult`.
- 화면: `/tmp/PF006-attachments/7DAE1316-97F4-4063-A0A0-341B26CA4024.png`.

필터 결과, 출력 저장, 실제 사진 선택 및 전체 접근성 검증은 후속 범위입니다.

## PF-007 실행 증거 — 2026-09-11

Xcode 26.6 / iPhone 17 Pro / iOS 26.5, TEST SUCCEEDED. 단위 13개 및 UI 2개, 총 15개 통과, 실패 0개.

추가 모델 테스트 6개는 초기화와 원본 보존, 사진 교체 시 설정 초기화, 실패 후 원본 제거·재시도 복구, 강도 범위/비유한 값 처리, 늦은 입력 결과 배제, 요청 취소 후 idle 복귀를 확인합니다. 순서·취소 테스트는 continuation으로 응답 순서를 제어하여 고정 대기 시간에 의존하지 않습니다. 기존 샘플 화면 이동 UI 테스트도 통과했습니다.

- 로그: `/tmp/PictureFilterApp-PF007.log`.
- 결과: `/tmp/PictureFilterApp-DerivedData/Logs/Test/Test-PictureFilterApp-2026.09.11_08-04-45-+0900.xcresult`.

실제 필터 픽셀 연산과 결과 저장은 이번 검증에 포함되지 않습니다.

## PF-008 실행 증거 — 2026-09-14

Xcode 26.6 / iPhone 17 Pro / iOS 26.5에서 TEST SUCCEEDED. 단위 17개 및 UI 3개, 총 20개 통과, 실패 0개.

새 렌더러 테스트는 모든 필터의 강도 0=원본, 흑백 채널 일치, 따뜻함/차가움 채널 변화, 세피아 색상, 중간 강도 범위, 반복 선택의 비누적, 미리보기 축소 크기 및 잘못된 입력 거부를 확인합니다. UI 테스트는 세피아 선택·강도 조작·원본 비교 후 설정 유지·초기화를 확인합니다. 캡처에서 세피아 효과와 선택 표시를 확인했습니다.

- 로그: `/tmp/PictureFilterApp-PF008.log`.
- 결과: `/tmp/PictureFilterApp-DerivedData/Logs/Test/Test-PictureFilterApp-2026.09.14_15-15-22-+0900.xcresult`.
- 캡처: `/tmp/PF008-attachments/F6B39CDB-0F8C-4FDC-A4AE-9BA29D487480.png`.

고해상도 연속 조작 성능, 자연 사진 품질과 실제 폰 검증, 최종 파일 저장은 후속 항목입니다.

## PF-009 실행 증거 — 2026-09-14

Xcode 26.6 / iPhone 17 Pro / iOS 26.5에서 TEST SUCCEEDED. 단위 22개·UI 3개, 총 25개 통과 및 실패 0개.

추가 테스트 5개: 늦은 성공이 최신 결과를 덮어쓰지 않음, 사진 교체 후 늦은 오류가 진행 표시/오류 상태를 덮어쓰지 않음, 조용한 구간 전에 쌓인 요청 중 최종 설정만 제출, 렌더 전 취소 시 미제출/오류 없음, 동일 설정 요청 무시. continuation으로 대기와 응답 순서를 제어하여 고정 sleep 시간 없이 검증했습니다. 기존 필터 조작·초기화·샘플 교체 UI 테스트도 통과했습니다.

- 로그: `/tmp/PictureFilterApp-PF009.log`.
- 결과: `/tmp/PictureFilterApp-DerivedData/Logs/Test/Test-PictureFilterApp-2026.09.14_15-48-05-+0900.xcresult`.

이 결과는 요청 처리의 정확성 검증입니다. 실제 폰의 고해상도 처리 시간·메모리·발열 검증은 PF-019에서 수행합니다.

## PF-010 실행 증거 — 2026-09-25

Xcode 26.6 / iPhone 17 Pro 시뮬레이터 / iOS 26.5에서 `TEST SUCCEEDED`.

- 단위 테스트 24개와 UI 테스트 4개, 총 28개 통과 및 실패 0개.
- `EditorModelTests`에서 picker 데이터의 편집 모델 주입·원본 데이터 보존·방향 메타데이터 유지·잘못된 데이터 오류 상태를 검증했습니다.
- UI 테스트에서 실제 아이폰 연결 없이 편집 화면의 시스템 사진 선택 버튼이 노출되는지 확인했습니다.
- 전체 실행 로그: `/tmp/PictureFilterApp-PF010-Final.log`.
- 결과 번들: `/tmp/PictureFilterApp-PF010-FinalDerivedData/Logs/Test/Test-PictureFilterApp-2026.09.25_19-22-01-+0900.xcresult`.

시뮬레이터 사진 선택 결과, 실제 시스템 권한 거부 및 iCloud 다운로드는 실기기·OS 수동 확인 대상으로 남습니다. 앱의 거부 오류 화면은 PF-012의 실패 대역 테스트로 검증합니다.

## PF-011 실행 증거 — 2026-09-26

Xcode 26.6 / iPhone 17 Pro 시뮬레이터 / iOS 26.5에서 앱 빌드 성공.

- 전체 실행: 단위 테스트 26개와 UI 테스트 5개, 총 31개 통과 및 실패 0개.
- 렌더러 테스트에서 출력이 JPEG이고 원본 방향과 640×480 픽셀 크기를 보존하는지 확인했습니다.
- UI 테스트에서 파일 가져오기 버튼과 파일·사진 앱 내보내기 메뉴 항목을 확인했습니다.
- 별도 UI 테스트에서 시뮬레이터에 `photos-add` 권한을 부여한 후 사진 앱 저장 완료 상태를 확인했습니다.
- 빌드 로그: `/tmp/PictureFilterApp-PF011-build.log`.
- 전체 테스트 로그: `/tmp/PictureFilterApp-PF011-test.log`.
- Photos 저장 테스트 로그: `/tmp/PictureFilterApp-PF011-photo-save.log`.

권한 승인 이후 저장 경로는 확인했습니다. PF-012에서 권한 거부 안내를 대역으로 검증했으며, iOS 설정 앱에서 재승인하는 OS 흐름은 수동 확인 대상으로 남습니다. 파일 내보내기 창에서 위치 선택 후 가져오기 창에서 같은 파일을 고르는 전체 상호작용은 아직 별도로 확인하지 않았습니다.

## PF-012 실행 증거 — 2026-09-26

Xcode 26.6 / iPhone 17 Pro 시뮬레이터 / iOS 26.5에서 `TEST SUCCEEDED`.

- 전체 실행: 단위 테스트 26개와 UI 테스트 9개, 총 35개 통과 및 실패 0개.
- 권한 거부 대역: 안내 문구, 설정 열기, 다시 저장 버튼을 확인했습니다.
- 저장 실패 대역: 실패 안내와 재시도 버튼이 나타나며 재시도 동작이 다시 실행됨을 확인했습니다.
- 지연 저장 대역: 처리 중 안내가 표시되고 내보내기 메뉴가 비활성화된 뒤 성공 상태로 바뀌는지 확인했습니다.
- 취소·실패 안내와 실제 사진 저장 흐름까지 기존 UI 회귀 테스트도 통과했습니다.
- 로그: `/tmp/PictureFilterApp-PF012-Final.log`.

실제 시스템 권한을 거부한 뒤 iOS 설정 앱에서 다시 허용하는 절차는 OS 화면 자동화가 필요해 수동 확인 항목으로 남아 있습니다. 자동 테스트는 권한 거부 대역으로 앱의 안내와 설정 이동 버튼을 확인했습니다.

## PF-013~PF-016 검증 및 MVP 검토 — 2026-09-26

Xcode 26.6 / iOS 26.5 / iPhone 17 Pro 시뮬레이터에서 자동화 스크립트와 전체 테스트를 검증했습니다.

- `scripts/build-ios.sh`: 빌드 성공.
- `scripts/test-ios.sh`: 총 36개 통과, 실패 0개(단위 테스트 26개, UI 테스트 10개).
- `scripts/run-simulator.sh`: Simulator 부팅 상태 확인, 빌드·앱 설치·앱 실행 성공. Bundle ID `com.local.PictureFilterApp` 실행 PID 확인.
- `.vscode/tasks.json`: JSON 파싱 통과. `bash -n`으로 네 셸 스크립트 문법 통과.
- 테스트 결과 번들: `.build/DerivedData/Logs/Test/Test-PictureFilterApp-2026.09.26_13-20-19-+0900.xcresult`.
- 작은 화면 iPhone 17e: `testSampleSelectionChangeAndReturn` 및 `testEditorRemainsAccessibleAtLargestDynamicType`, 2개 통과, 실패 0개. 결과: `.build/DerivedData/Logs/Test/Test-PictureFilterApp-2026.09.26_13-53-49-+0900.xcresult`.

PF-014 자동 테스트는 필터 반복 적용의 비누적성, 초기화 후 원본 보존, 빠른 설정 변경 시 최신 렌더 반영, 결과 JPEG 재디코딩과 방향·픽셀 크기를 확인합니다. PF-015 UI 테스트에서는 샘플 진입, 세피아 적용 후 사진 저장, 최대 Dynamic Type에서 편집 컨트롤 접근을 확인했습니다.

작은 화면 iPhone 17e의 전체 테스트 스위트는 OS Photos 권한 및 저장 진행 테스트에서 완료되지 않았습니다. 대신 권한 UI에 의존하지 않는 작은 화면 핵심 케이스를 독립 실행해 두 테스트 모두 통과했습니다. 샘플→편집→저장 경로는 iPhone 17 Pro의 전체 UI 스위트에서 통과했습니다. 따라서 소형 화면·큰 글자와 저장 흐름을 대상별로 검증했습니다.

### 정지 이미지 MVP 검토

현재 시제품은 샘플·PhotosPicker·파일에서 정지 이미지를 입력받고, 원본·흑백·세피아·따뜻함·차가움 필터와 강도를 미리보기로 조절합니다. 원본 비교·초기화·JPEG 출력, 파일 내보내기 및 Photos 저장 경로가 구현되어 시뮬레이터에서 자동 테스트됩니다.

검증 결과는 정지 이미지 편집 프로토타입 범위입니다. 실기기 Photos 권한 거부·설정 복구는 PF-018에서 통과했습니다. iCloud 전용 다운로드 실패의 실시간 재현은 사진 원본이 기기에 남아 있는지 신뢰성 있게 통제하기 어려워 사용자 결정으로 생략했습니다. 앱의 일반 입력 실패 상태는 단위 테스트로 확인했습니다. 12MP 합성 색상표의 크기·색상·반복 렌더 속도와 단기 열 상태는 PF-019에서 실기기로 확인했습니다. 자연 사진의 필터 품질과 장시간/대용량 처리 성능은 합성 색상표와 짧은 반복 테스트만으로 보증하지 않습니다.

## PF-021 카메라·피부 보정 검증 — 2026-09-26

Xcode 26.6 / iPhone 17 Pro 시뮬레이터 / iOS 26.5에서 앱과 테스트 타깃 빌드 및 전체 자동 테스트를 실행했습니다.

- 카메라 촬영 버튼과 피부 보정 슬라이더가 편집 화면에 노출되는지 확인했습니다.
- 시뮬레이터에서 촬영 버튼을 누르면 카메라 미지원 안내가 표시됩니다. 실기기 카메라 캡처는 이번 환경에서 실행하지 않았습니다.
- 편집 상태 테스트에서 피부 보정 강도 제한, NaN 무시, 설정 변경 시 새 미리보기 요청, 초기화를 확인했습니다.
- 테스트용 인물은 AI로 생성한 가상 인물이며 로컬 리소스 `PictureFilterAppTests/Resources/Fixtures/synthetic-face.jpg`로만 보관합니다. 인터넷 공개 인물 사진이나 실제 사용자 사진은 테스트 자료로 사용하지 않습니다.
- `scripts/validate-face-smoothing-macos.sh` 실행으로 macOS Vision이 가상 인물 얼굴 1개와 랜드마크를 검출하는지 확인했습니다. 강도 0.8에서 10,810 픽셀 변화가 얼굴 영역에 집중됐고 결과를 눈으로 검토했습니다. 비교 출력은 `.build/PF021-synthetic-face-retouched.png`입니다.
- 시뮬레이터 Vision 추론은 inference context 오류를 반환해, 구현은 렌더·저장이 중단되지 않도록 원본을 유지합니다. iOS 테스트는 합성 사진으로 렌더 경로와 안전한 출력을 검사합니다. 실제 iPhone의 Vision 실행·성능 및 인물별 보정 품질은 PF-018~PF-019에서 확인합니다.
- 전체 실행은 단위 29개·UI 11개, 총 40개 통과 및 실패 0개.
- 결과 번들: `.build/PF-021-Verified.xcresult`.

카메라 권한·실제 촬영 결과·인물별 보정 품질과 고해상도 처리 성능은 열린 항목 PF-018~PF-019에서 확인합니다.

<a id="pf-024-인물별-자연-보정-검증"></a>

## PF-024 인물별 자연 보정 검증 — 2026-09-26

iPhone 16 Pro Max에서 Vision 얼굴 검출과 피부 마스크 렌더링을 검증했습니다. 사용자 개인 사진은 사용하지 않았습니다.

- 실기기 전체 단위 테스트 38개 통과: `.build/PF024-Device-Final.xcresult`.
- 합성 사진 두 장을 한 프레임에 배치해 2인 사진을 만들고 왼쪽·오른쪽 대상만 각각 보정되는지 픽셀 비교로 확인했습니다. 비선택 인물 영역의 차이는 0이고 선택 영역은 변했습니다.
- 인물 검출 결과 개수 표시, 개인 선택, 강도 조절, 선택 인물 초기화와 사진 교체 시 초기 설정 복원을 모델 테스트로 확인했습니다.
- UI 자동화에서 얼굴이 없는 사진은 원본 유지 안내를 표시하고 인물 선택 UI를 노출하지 않는 것을 확인했습니다. 테스트 1개 통과: `.build/PF024-UI-Final-Retry.xcresult`.
- 시뮬레이터 iOS 26.5에서는 Vision inference context 오류가 나 얼굴 분석에 실패하지만 앱은 원본을 그대로 유지합니다. 해당 경로는 UI 테스트로 확인했고, 실제 얼굴 검출·보정은 실기기 테스트에서 검증했습니다.
- 실제 인물 사진은 Wikimedia Commons의 `Headshot 2026.jpg`(Mdb1909, CC0)를 임시 로컬 테스트 입력으로 사용했습니다. 강도 0.25·0.5·1.0으로 렌더한 결과에서 눈·입·수염·머리카락의 경계가 유지되고 피부 결이 남는 점을 눈으로 확인했습니다. 최대 강도에서도 얼굴 형태나 피부색을 바꾸지 않고 효과는 절제된 수준이었습니다. 원본 테스트 사진은 검토 후 저장소에서 제거했습니다. [원본 출처와 CC0 표기](https://commons.wikimedia.org/wiki/File:Headshot_2026.jpg); 결과와 비교 이미지는 `.build/PF024-PublicPortrait-Final.xcresult`에 있습니다.

보정 결과는 온디바이스에서 처리되며 원본 비교와 전체/개별 초기화를 지원합니다. 공개 스킬은 실행 가능한 iOS 피부 마스크 알고리즘을 제공하지 않아 의존성이나 앱 코드에 추가하지 않았습니다.

## PF-017 실기기 서명·설치·실행 — 2026-09-26

iPhone 16 Pro Max (iOS 26.6.2)에서 USB 연결·페어링·개발자 모드를 확인했습니다. Personal Team을 사용해 기기용 서명 빌드와 설치를 수행했고 `codesign --verify --deep --strict`가 통과했습니다. 최초 실행은 기기에서 개발자 앱을 신뢰하기 전 차단됐습니다. 사용자가 iPhone에서 신뢰를 승인한 뒤 `devicectl` 실행 요청이 성공해 앱 실행을 확인했습니다. 상세 작업 상태는 [PF-017 보관 항목](TASKS_ARCHIVE.md#pf-017)에 있습니다.

## PF-018 실기기 사진 저장·선택 — 2026-09-26

iPhone 16 Pro Max (iOS 26.6.2)에서 테스트용 합성 색상표를 편집해 Photos에 저장했습니다. UI 테스트에서 성공 상태를 확인한 뒤 PhotosPicker를 열고 방금 저장한 색상표를 선택해 앱 편집 화면으로 다시 불러왔습니다. 저장 및 선택 경로는 실기기에서 통과했습니다.

- 저장 결과: `.build/PF018-DeviceDerivedData/Logs/Test/Test-PictureFilterApp-2026.09.26_18-27-48-+0900.xcresult`.
- PhotosPicker 선택 결과: `.build/PF018-DeviceDerivedData/Logs/Test/Test-PictureFilterApp-2026.09.26_18-39-57-+0900.xcresult`.
- 실기기 거부·재시도 UI 대역 테스트 2개 통과: `.build/PF018-DeviceDerivedData/Logs/Test/Test-PictureFilterApp-2026.09.26_18-41-29-+0900.xcresult`.
- 앱의 사진 설정 바로가기가 iOS의 PictureFilterApp 설정 화면을 여는지 실기기에서 확인: `.build/PF018-DeviceDerivedData/Logs/Test/Test-PictureFilterApp-2026.09.26_18-48-55-+0900.xcresult`. 설정 화면에서 현재 Photos 권한은 `사진 추가만`으로 확인했습니다.
- 원본 데이터가 필터 변경·초기화 뒤에도 유지되는 단위 테스트가 실기기 테스트 런에서 통과: `.build/PF018-DeviceDerivedData/Logs/Test/Test-PictureFilterApp-2026.09.26_18-51-20-+0900.xcresult`. Photos 저장 구현은 원본 자산을 수정하지 않고 새 PHAsset을 생성합니다.
- 실제 iOS Photos 접근을 `안 함`으로 변경했을 때 앱 저장이 권한 거부 상태를 표시하고, 설정에서 `사진 추가만`으로 되돌린 뒤 저장이 성공하는 전체 흐름이 통과했습니다: `.build/PF018-DeviceDerivedData/Logs/Test/Test-PictureFilterApp-2026.09.26_18-59-38-+0900.xcresult`. 테스트 종료 시 원래 권한 상태를 다시 저장 성공으로 확인했습니다.
- 첫 선택 테스트는 시스템 선택기의 접근성 요소가 일반 컬렉션 셀이 아닌 이미지로 제공되는 점을 반영해 수정했고, 수정 후 실기기에서 통과했습니다.

내장 드라이브 작업본에서도 iPhone 16 Pro Max (iOS 26.6.2)로 저장과 PhotosPicker 재선택을 각각 다시 실행해 1개씩 통과했습니다. 두 실행은 합성 색상표만 사용했으며 사용자 사진을 열지 않았습니다.

- 저장 결과: `.build/PF018-InternalDeviceDerivedData/Logs/Test/Test-PictureFilterApp-2026.09.26_20-07-59-+0900.xcresult`.
- PhotosPicker 재선택 결과: `.build/PF018-InternalDeviceDerivedData/Logs/Test/Test-PictureFilterApp-2026.09.26_20-08-55-+0900.xcresult`.

실제 Photos 저장 권한 거부→설정 복구→저장 성공은 iPhone 16 Pro Max에서 통과했습니다. iCloud 오프라인 검증용으로 사용자가 올린 샘플을 선택해 편집 화면에 표시되는 것을 확인했지만, 비행기 모드 상태를 확인하지 못해 이를 네트워크 실패/성공 판정으로 쓰지 않았습니다. 사용자는 iCloud 전용 상태를 강제하는 난이도에 비해 검증 이득이 낮다고 판단해 실제 다운로드 실패 재현을 생략했습니다. 일반 입력 실패는 편집 모델 대역 테스트에서 확인했습니다.

샘플 파일은 촬영 시각 메타데이터가 없고 파일 생성일이 2026-09-09 21:47 KST이므로 iPhone 사진 타임라인의 해당 날짜 구간에 놓일 수 있습니다. PhotosPicker로 사용자가 선택한 샘플은 편집 화면까지 정상 로드됐습니다. [Apple Support: iCloud Photos와 기기 저장 공간 최적화](https://support.apple.com/guide/iphone/sync-photos-videos-icloud/27/ios/27).

<a id="pf-025-인물-조명과-배경-깊이-효과"></a>

## PF-025 인물 조명과 배경 깊이 효과 — 2026-09-26

- iPhone 16 Pro Max 전체 단위 테스트 41개 통과: `.build/DerivedData/Logs/Test/Test-PictureFilterApp-2026.09.26_22-04-09-+0900.xcresult`.
- 합성 두 인물 테스트에서 왼쪽 얼굴 조명만 달라지고 오른쪽 얼굴 픽셀은 유지됨을 확인했습니다: `FilterRendererTests.testPortraitLightChangesOnlySelectedSyntheticFace` (`22-03-31` 결과).
- Vision 사람 인스턴스 마스크를 사용한 배경 흐림 테스트에서 배경 변화와 얼굴 중앙 보존을 확인했습니다: `FilterRendererTests.testBackgroundBlurUsesOnDevicePersonMask` (`22-03-57` 결과).
- 시뮬레이터 UI 테스트에서 새 조명·배경 흐림 조절부 표시와 얼굴이 검출되지 않을 때의 안내 및 조명 비활성화를 확인했습니다. 전체 시뮬레이터 실행은 54개 중 50개 통과, 4개 실패였습니다. 3개는 시뮬레이터 Vision 추론이 지원되지 않아 얼굴 분석 기대값을 만족하지 못했고, 1개는 사진 권한 복구 UI 테스트 실패입니다. 따라서 시뮬레이터 전체 실행은 통과로 보지 않았습니다.
- UI 레이아웃 재정리 후 관련 시뮬레이터 UI 테스트 2개를 다시 실행해 통과했습니다: `.build/DerivedData/Logs/Test/Test-PictureFilterApp-2026.09.26_22-07-49-+0900.xcresult`.
- `VNGeneratePersonInstanceMaskRequest`의 인물 마스크를 합쳐 전경으로 사용하므로 다중 인물 사진의 배경 흐림에서는 모든 감지 인물을 보존합니다. 사람 마스크가 없거나 Vision 요청이 실패하면 원본을 유지합니다. 새 기능의 실기기 검증은 합성 두 인물 사진에 한정하며 자연 사진의 모발 경계·복잡한 가림·주관적 조명 품질 검증은 후속 보완 대상으로 남습니다.

## PF-019 실기기 품질·성능 검증 — 완료

12MP 합성 색상표(`4032×3024`)를 테스트 전용 리소스로 추가했습니다. 원본 크기와 12개 색상 패치의 RGB 평균, 미리보기 및 JPEG 원본 크기 출력 40회 반복을 실기기에서 확인했습니다.

- iPhone 16 Pro Max (iOS 26.6.2): 전체 단위 테스트 31개 통과, 결과 `.build/PF019-Device-FinalSuite.xcresult`.
- JPEG 출력 크기 `4032×3024`; 12개 색상 패치 평균은 각 RGB 채널 기준 목표값 ±12 이내.
- 40회 미리보기(1600px) + 원본 크기 JPEG 출력 반복: 평균 `183.0 ms`, 중앙값 `183.2 ms`, 최대 `185.8 ms`. 열 상태는 10회 간격 표본 및 종료 시 모두 `nominal`.
- 검증은 합성 색상표를 이용한 짧은 반복 부하입니다. 60회 탐색 실행 하나는 signal kill로 끝났으나 원인은 확인되지 않았습니다. 따라서 장시간 발열, 메모리 한계, 자연 사진에서의 주관적 색감 품질은 검증 완료로 간주하지 않습니다. 출시 전 실제 사진 및 장시간 부하 검증이 필요해지면 별도 작업으로 등록합니다.


<a id="portrait-camera-acceptance"></a>

## 후속 수용 검증 · 화사한 인물 사진과 배율 촬영

다음은 후속 검증 계획입니다. PF-026 회귀 검증은 완료했고 PF-027 구현·시뮬레이터 검증은 [아래 기록](#pf-027)을 참고합니다. 촬영 환경별 화사함 수용 검증과 나머지 항목은 **미실행**입니다. 기존 테스트 통과 수치를 새 요구의 완료 증거로 사용하지 않습니다.

| 검증 범위 | 확인할 시나리오 | 담당 작업 |
| --- | --- | --- |
| 다중 인물 편집 | 합성 두 인물 회귀 검증 완료. 결과와 범위는 [PF-026](#pf-026) 참조 | PF-026 완료 |
| 화사한 결과 | 다양한 피부색, 실내 혼합광·역광·저조도, 원본/기본/최대 강도 비교. 밝은 부분 잘림과 피부색 변화·질감 손실을 평가 | PF-027·PF-031 |
| 실제 촬영 | 전후면, 최소/최대/중간 배율, 렌즈 경계, 핀치·슬라이더·버튼 연속 조작. 미리보기와 저장 화각·방향·미러링 | PF-028·PF-029·PF-031 |
| 사용 흐름 | 샘플 없이 시작 → 촬영 → 필터 → 비교 → 저장, 취소·재촬영·권한 거부/복구·세션 중단 | PF-030·PF-031 |
| 경계·해상도 | 모발·수염·안경·옆얼굴·가림·다중 인물, 1600px와 4096px 결과를 같은 표시 크기로 비교 | PF-032 |
| 응답·상태 | 분석 중/얼굴 없음/실패, 사진 교체, 빠른 강도 변경, 모든 효과 조합의 지연·메모리·열 상태 | PF-033 |
| 실행 신뢰도 | 여러 시뮬레이터 런타임에서 대상 선택, Vision 실제 추론은 실기기 필수, 사진 권한 UI 실패 재현 | PF-034 |

공개 자료의 사용 조건 또는 사진 제공자의 동의를 확인하고 평가 자료에 피부색·촬영 조명·효과 강도·해상도·기기/OS를 기록합니다. 밝기 개선과 하이라이트 손실의 허용 기준은 대표 자료를 선정할 때 정하고 사용자 전후 비교 리뷰와 함께 판정합니다. 개인 사진은 별도 동의 없이 저장소에 넣지 않습니다. 보유하지 않은 기기의 배율·렌즈 전환은 대역 검증만으로 실기기 통과로 기록하지 않습니다.

<a id="pf-026"></a>

## PF-026 인물별 보정 유지와 개별 끄기 — 2026-09-26

- iPhone 16 Pro Max (iOS 26.6.2): 전체 단위 테스트 **45개 통과, 실패·건너뜀 0개**. 결과: `.build/PF026-Device-Final.xcresult`.
- 합성 두 인물에 서로 다른 피부·조명 강도를 설정하고 A/B/전체 선택을 전환해도 PNG 미리보기와 JPEG 출력 데이터가 각각 동일함을 확인했습니다. 각 효과를 별도로 검증했으며 양쪽 인물 영역에 변화가 있음을 확인했습니다.
- 전체 기본 강도가 0.6인 상태에서 A 효과를 끄면 A는 해당 효과 적용 전으로 돌아가고 B는 유지됩니다. PNG/JPEG 모두 독립적으로 만든 B만 보정한 기대 결과와 일치합니다. 이는 피부·조명별 복구이며 다른 필터와 배경 효과까지 지우는 기능은 아닙니다.
- 모델 테스트에서 선택만 바꿀 때 미리보기 갱신이 발생하지 않음, 전체 강도 조절 시 해당 효과의 개별값만 제거됨, 다른 효과 유지 및 전체 초기화를 확인했습니다.
- iPhone 17 Pro 시뮬레이터 (iOS 26.5): 얼굴 미검출 시 보정 안내·원본 유지 및 시스템 사진 선택기 관련 UI 테스트 **2개 통과**. 결과: `.build/PF026-UI.xcresult`. 전체 시뮬레이터 테스트를 다시 실행한 것은 아닙니다.
- 최초 실기기 실행은 44개 통과·1개 실패였습니다. 약한 피부 보정의 JPEG 평균 차이 0.005423이 테스트의 0.01 기준보다 작았습니다. 이 회귀 테스트는 효과 강도 품질이 아니라 편집 소실을 검사하므로 변화 존재(0 초과)를 확인하도록 수정했습니다. 선택 전환의 바이트 일치 및 개별 복구의 기대 결과 일치 검사는 유지했습니다.
- macOS 보조 스크립트는 오래된 함수 호출을 수정해 컴파일되지만 실행은 **실패**했습니다. RGB 차이 8 초과 픽셀이 140개로 기존 1,000개 초과 기준을 만족하지 못했습니다. 결과: `.build/PF026-MacValidation.log`. 임계값을 임의로 낮추지 않고 PF-034의 평가 기준 보완으로 남깁니다.

이번 완료 범위는 인물별 편집 상태와 렌더링 일관성입니다. 자연 인물 사진의 주관적 화사함·피부 질감·경계 품질 평가는 PF-027·PF-031·PF-032에서 진행합니다.


<a id="pf-027"></a>

## PF-027 화사한 인물 · 시뮬레이터 구현 검증 — 2026-09-30

**구현과 시뮬레이터 검증 완료, 촬영 환경별 대표 사진 품질 확인은 미완료**입니다. 이후 사용자 요청으로 PF-027 구현은 닫고 남은 품질 검증은 [PF-035 검증표](PORTRAIT_VALIDATION.md)로 분리했습니다. 이번 실행에는 연결된 실제 iPhone을 사용하지 않았습니다.

- 환경: iPhone 17 Pro 시뮬레이터, iOS 26.5, 장치 ID `9533B106-C319-4D9A-8527-0AB609143CCB`. 이름+최신 런타임 자동 선택 대신 명시한 ID로 실행했습니다.
- 결과: **단위 테스트 44개 + UI 테스트 2개 = 46개 통과, 실행 중 실패·건너뜀 0개**. 결과 묶음은 `.build/PF027-Simulator-Final.xcresult`, 실행 로그는 `.build/PF027-Simulator-Final.log`입니다. 실행 대상으로 선택하지 않은 테스트는 이 수에 포함되지 않습니다.
- 전체 단위 테스트 중 실제 얼굴/피부/분할 경로 관련 8개와 실기기 고해상도 반복 성능 1개를 실행 대상에서 제외했습니다. 제외한 메서드는 `EditorModelTests.testEditorDetectsMultiplePeopleInSyntheticImage`, `FilterRendererTests`의 `testExpressiveStylesKeepGeneratedPortraitFaceDetectable`, `testSyntheticPortraitFixtureExercisesSkinSmoothingRenderPath`, `testPersonSelectionSmoothsOnlySelectedSyntheticPortrait`, `testPortraitLightChangesOnlySelectedSyntheticFace`, `testBothPeopleKeepTheirEditsAcrossSelectionInPreviewAndExport`, `testIndividualResetRestoresOnlyThatPersonDespiteNonzeroGlobalStrength`, `testBackgroundBlurUsesOnDevicePersonMask`, `testRepeatedHighResolutionPreviewAndOutputRecordsSpeedAndThermalState`입니다. 기존 실기기 검증을 시뮬레이터 통과로 다시 세지 않았습니다.

| 검사 | 확인한 결과와 범위 |
| --- | --- |
| 원본 보존 | 프리셋 강도 0 및 밝기·따뜻함 모두 0일 때 PNG/JPEG가 각각 원본 렌더와 동일. 원본 데이터, 초기화, 사진 교체 기본값 확인 |
| 계조 보호 | 0·32·64·128·192·224·240·248·255 회색 패치에서 순서 유지, 그림자·중간 밝기 증가, 248 패치 증가 2 이하, 검정/흰색 유지 |
| 피부색 범위 | 서로 다른 밝기의 피부색 합성 패치 4개에 최대 밝기와 따뜻함 -1/0/1 적용. 가중 밝기 증가, 채널 순서 보존, 클리핑 없음, 상대 채도 변화 0.08 미만 |
| 얼굴 영역 | 고정 얼굴 사각형 2개를 주입해 양쪽 영역의 추가 밝기와 영역 사이의 전체 보정값 유지 확인. 편집 대상 선택으로 프리셋 결과 불변 |
| 미리보기/저장 | 같은 고정 얼굴 영역을 사용한 512px PNG와 1024px JPEG의 대응 영역이 RGB 채널별 오차 3 이내. 실제 검출기의 해상도별 영역 동일성을 의미하지 않음 |
| 검출 대안 | 실제 검출기를 사용하되 얼굴 없는 입력에서도 전체 톤 보정 결과 생성. 분석 실패와 얼굴 없음은 모두 전체 보정으로 처리 |
| 화면과 저장 | 새 프리셋 선택 → 밝기·따뜻함 조절 → 원본 누름 비교 후 복귀 → 시뮬레이터 Photos 저장 성공 → 초기화. 기존 얼굴 미검출 안내 UI 회귀도 통과 |

최초 실행은 9개 통과·1개 실패였습니다. 밝은 피부색 패치에서 강한 차가운 색감 설정이 밝기 증가를 상쇄했습니다. 따뜻함을 색 채널 간 공통 여유 범위로 제한하고 가중 밝기를 유지하도록 수정했으며, 밝기 평가는 단순 RGB 합 대신 가중 밝기로 확인합니다. 사전 이미지 비교에서 효과가 약해 중간 밝기 증가량도 조정했고, 최종 회귀 테스트가 통과했습니다. 실행 묶음에 내부 QoS 대기 경고 1개가 남았으며 성능 원인 분석은 PF-033에서 추적합니다.

### 이미지 사전 비교

- 합성 인물: 원본·기본 강도 0.5·최대 강도 1.0 첨부가 `.build/PF027-Simulator-Final.xcresult`에 있습니다. 내보낸 파일은 `.build/PF027-final-attachments/`에 보관합니다. 얼굴 영역은 고정 좌표를 주입했으므로 시뮬레이터 Vision 성공 사례가 아닙니다.
- 공개 인물 이미지: [Headshot 2026.jpg · Mdb1909 · CC0](https://commons.wikimedia.org/wiki/File:Headshot_2026.jpg)를 임시 입력으로 사용했습니다. **macOS**에서 앱과 같은 렌더링 소스와 실제 검출기를 실행해 얼굴 1개를 확인했습니다. `.build/PF027-PublicReview.log`와 `.build/PF027-public-0.0.png`, `-0.5.png`, `-1.0.png`에 결과를 보관합니다. 원본 및 출력은 Git에 추가하지 않습니다.
- 전후 육안 확인에서 얼굴의 어두운 부분이 밝아지고 눈·수염·머리카락의 형태와 세부 질감은 유지됐습니다. 최대 강도는 기본보다 밝지만 얼굴을 흐리게 하거나 흰 부분을 넓게 만들지는 않았습니다. 이 한 이미지의 촬영 환경·생성 방식은 별도로 검증하지 않았으며 실제 실내·야외·역광 촬영 평가의 증거로 쓰지 않습니다.
- 남은 수용 기준: 실제 촬영 환경별 대표 사진, 다양한 피부색·흰옷·강한 역광·가림의 기본/최대 강도 비교 및 사용자 품질 리뷰. 이 조건은 PF-035에서 이어가며 PF-027 구현은 완료 처리했습니다. 실제 촬영 통합 평가는 PF-031에서 이어갑니다.


<a id="pf-028"></a>

## PF-028 전용 카메라 · 구현 및 자동 검증 — 2026-09-30

**전용 촬영 기능 구현과 자동 검증 완료, 실기기 확인 대기**입니다. `devicectl` 조회에서 iPhone 16 Pro Max는 `unavailable`이었으므로 사진 촬영·플래시 발광·실제 권한 화면·시스템 인터럽트가 성공한 것으로 기록하지 않습니다.

- 카메라 집중 검증: 모델 테스트 10개와 UI 테스트 2개, **12개 통과**. `.build/PF028-Camera.xcresult`.
- 최종 회귀 검증: iPhone 17 Pro 시뮬레이터 iOS 26.5, **단위 54개 + UI 4개 = 58개 통과**, 실패·건너뜀·런타임 경고 0개. `.build/PF028-Final.xcresult`, `.build/PF028-Final.log`. PF-027과 같은 9개 실기기 관련/반복 성능 테스트를 실행 대상에서 제외했습니다. 전체 실기기 테스트 통과를 뜻하지 않습니다.
- `generic/platform=iOS` 기기용 Debug 빌드도 성공했습니다. `.build/PF028-DeviceBuild-Final.log`. `CODE_SIGNING_ALLOWED=NO`로 컴파일했으며 설치·서명·촬영 성공의 증거는 아닙니다.

| 자동 검증 시나리오 | 확인 결과 |
| --- | --- |
| 권한 및 미지원 | 대역의 거부 → 허용 → 시작 복구, 실제 시뮬레이터 서비스의 미지원 상태 |
| 제어 | 전후면 전환 시 미지원 플래시 끄기, 노출 초기화, 장치 범위 제한, NaN 무시, 준비 상태에서만 초점 전달 |
| 데이터·중복 | 첫 촬영 대기 중 두 번째 셔터와 전환 차단. 촬영 바이트와 편집기 originalData가 동일하여 재압축 없음 |
| 취소·지연 | 촬영 중 닫기 뒤 늦은 결과 폐기. 시작/권한 대기 중 백그라운드 진입 후 늦은 시작 결과가 화면을 다시 열지 않음 |
| 중단·실패 | 대역 인터럽트 이벤트 동안 셔터 차단, 복구 이벤트 후 준비 상태, 닫힌 화면은 복구 이벤트 무시. 잘못된 데이터·촬영 오류 후 재시도 가능. 런타임 오류 후 재시도 |
| 노출 복귀 | 백그라운드 후 시작에서 서비스의 실제 노출값을 화면에 반영 |
| 화면 통합 | Debug 대역으로 전후면 전환·노출 조절·촬영 → 편집 화면 데이터 전달 → 화사한 필터 선택. 재촬영 창 취소 시 기존 사진·필터 유지 |
| 일반 시뮬레이터 | 테스트 인자 없이 촬영 진입 시 미지원 안내. 새 필터 저장·얼굴 미검출 UI 회귀도 통과 |

### PF-028 실기기 확인 목록

아래는 **미실행**이며 대역 결과로 체크하지 않습니다. 가능하면 합성 색상표를 실제 카메라로 촬영하여 개인 사진이 결과에 남지 않게 합니다. 각 실행에 커밋·기기·OS·권한 상태·전후면·플래시/노출·원본 크기·결과를 기록합니다.

- [ ] **PF-028-V01 · 전후면 데이터 전달:** 실제 전후면 촬영 후 편집기로 전달, 원본 방향/크기 보관, 필터 적용·사진 저장·재열기. UIImage를 통한 입력 재압축이 없는지 확인.
- [ ] **PF-028-V02 · 권한 복구:** 최초 요청의 허용/거부, 설정에서 허용 후 복귀, 제한 상태와 취소. 거부 상태에서 설정 버튼·재시도 안내와 정상 복귀 확인.
- [ ] **PF-028-V03 · 장치 제어:** 화면 탭 초점·측광, 노출 최소/0/최대, 실제 지원 플래시 off/auto/on, 전후면 전환 뒤 미지원 항목 숨김과 노출값 일치. 플래시 발광을 직접 확인.
- [ ] **PF-028-V04 · 중단과 연속 입력:** 준비/촬영 중 홈 이동·잠금·앱 복귀, 가능한 시스템 카메라 점유/통화 인터럽트, 빠른 연속 셔터, 촬영 직후 취소와 재진입. 늦은 결과가 이전 사진을 덮지 않고 카메라 세션이 화면 종료 후 남지 않는지 확인.
- [ ] **PF-028-V05 · 구도와 오류 복구:** 세로 화면의 미리보기/저장 화각·방향·전면 비반전 일치, 기기를 기울이거나 돌렸을 때 결과 확인. 실제 처리 실패/시간 초과가 가능한 환경에서 재시도·취소 가능 여부를 기록. 재현하지 못한 오류는 미검증으로 남김.

기기 지원 배율·렌즈 전환은 PF-029, 촬영 중심 진입·재촬영 통합은 PF-030, 실제 촬영을 포함한 종합 수용은 PF-031입니다. PF-028의 실기기 조건이 끝날 때까지 상위 작업은 열린 상태로 유지합니다.


<a id="pf-034-selection"></a>

## PF-034 시뮬레이터 선택 안정화 — 2026-10-02

이번 범위는 실행 대상 선택 하위 작업입니다. 빌드·테스트·앱 실행 모두 공통 선택기로 설치된 사용 가능 iOS 장치를 확인하고 명시적 ID를 사용합니다. 이름이 여러 런타임에 존재하면 임의의 최신 OS를 선택하지 않고 후보 이름·런타임·ID와 지정 방법을 출력합니다. 명시한 ID가 없거나 런타임과 충돌해도 다른 장치로 대체하지 않습니다.

- `python3 scripts/test_simulator_selection.py`: **8개 통과**. 중복 이름, 이름+런타임, ID 우선 선택, ID/런타임 충돌, 사용 불가·없는 ID, 단일 이름, 비-iOS 제외를 합성 목록으로 검증.
- `bash -n scripts/lib.sh scripts/test-ios.sh scripts/build-ios.sh scripts/run-simulator.sh`: 통과.
- `bash scripts/test-ios.sh -only-testing:PictureFilterAppTests/CameraModelTests -resultBundlePath .build/PF034-SimulatorSelection.xcresult`: **10개 통과, 실패·건너뜀·런타임 경고 0개**. iPhone 17 Pro / iOS 26.5 / `9533B106-C319-4D9A-8527-0AB609143CCB`. 로그: `.build/PF034-SimulatorSelection.log`.
- iOS 26.5와 iOS 27.0이 설치된 환경에서 기본 이름을 실제 ID로 해석해 테스트했습니다. 같은 이름의 여러 런타임 충돌은 합성 목록에서 검사했습니다.
- 전체 회귀/UI 테스트, 실제 Photos 권한 복구, Vision 추론, 실기기 촬영, macOS 피부 보정 평가 기준은 이번 실행에 포함하지 않았습니다. PF-034 전체 완료를 의미하지 않습니다.

### PF-034 실행 분리·평가 기준·권한 실패 재현 — 2026-10-02

- `python3 scripts/test_test_profiles.py`: **4개 통과**. simulator의 9개 미실행 이름 보고, device의 실기기 ID 필수 조건, 실제 Vision/성능 9개 선택, 오타 프로필 중단을 검증했습니다. 실기기는 실행하지 않았습니다.
- 실기기 인물 조명 검사는 Vision 실패를 `XCTSkip`으로 숨기지 않고 검출 2명이라는 필수 조건을 검사하도록 수정했습니다. 실제 실기기 실행 결과는 미검증입니다.
- `bash scripts/validate-face-smoothing-macos.sh`: **통과**. `.build/PF034-MacValidation.log`. 합성 사진의 실제 macOS Vision 랜드마크 얼굴 1명, 강도 0 원본 바이트 일치, 얼굴 평균 채널 변화 0.37704(전체 흐림 4.83446), 페더 영역 밖 최대 변화 1/255. 비교 양쪽을 같은 Core Image 색 변환 경로로 렌더링했습니다. 이 수치는 실제 사진 피부 품질 또는 iPhone 추론 성공을 뜻하지 않습니다.
- 실제 Photos 권한 UI 테스트: **실패 재현**. `.build/PF034-Permission-Reproduction.xcresult` (1개 실패). iPhone 17 Pro / iOS 26.5에서 `openPhotoSettings` 뒤 Settings가 앱별 권한 화면 대신 루트 화면으로 열렸으며 `PHOTOS` 항목을 찾지 못했습니다. `.build/PF034-settings.txt` 접근성 계층으로 확인했습니다. 실제 권한 요청을 먼저 등록한 시도(`PF034-Permission-Registered.xcresult`)도 실패했고, Settings 검색으로 이동하는 시도(`PF034-Permission-Navigation.xcresult`)에서는 앱 이름 검색 결과가 없어 실패했습니다. 검증되지 않은 UI 수정은 되돌렸습니다. **권한 복구 성공으로 기록하지 않습니다.** 앱 내 거부 처리와 OS 설정 탐색 실패는 별개이며 다른 런타임 및 실기기 복구는 미검증입니다.
- 새 기본 simulator 프로필로 `bash scripts/test-ios.sh -only-testing:PictureFilterAppTests -resultBundlePath .build/PF034-UnitRegression.xcresult`: **54개 통과, 실패·건너뜀 0개**. 위 9개는 실행 대상에서 제외되어 통과 수에 포함되지 않습니다. iPhone 17 Pro / iOS 26.5. 내부 QoS 우선순위 대기 경고 1개가 남아 PF-033 성능 점검 대상으로 유지합니다. 로그 `.build/PF034-UnitRegression.log`.

<a id="pf-029"></a>

## PF-029 지원 배율·연속 줌 구현 — 2026-10-02

- `bash scripts/test-ios.sh -only-testing:PictureFilterAppTests/CameraModelTests -only-testing:PictureFilterAppUITests/LaunchTests/testDedicatedCameraCaptureAndCancelWithSimulatorStandIn -resultBundlePath .build/PF029-Zoom.xcresult`: **모델 15개 + UI 1개 = 16개 통과**, 실패·건너뜀·런타임 경고 0개. iPhone 17 Pro / iOS 26.5 / `9533B106-C319-4D9A-8527-0AB609143CCB`. 로그 `.build/PF029-Zoom.log`.
- 모델 검사: 표시/장치 배율 변환, 최소·최대·중간·렌즈 경계 입력, NaN/무한대 무시, 잘못된 범위 정규화, 중복/범위 밖 버튼 제외, 연속 입력의 마지막 값 유지, 적용 중 촬영·전후면 차단, 전면 1× 초기화, 취소 후 늦은 결과 폐기, 실패 후 조작 복구, 포맷 범위 변경 이벤트 및 중단 상태 보존.
- UI 대역: 후면 1× → 3× 버튼 → 전면 1× 초기화 및 미지원 경계 버튼 제거 → 슬라이더 → 촬영 → 편집기 전달 → 필터 → 재촬영 취소 후 유지. 대역의 합성 사진은 줌에 따라 화각이 변하지 않으므로 이 검사는 실제 화각 일치의 증거가 아닙니다. 실제 preview의 핀치 제스처는 구현·컴파일됐으며 실제 카메라 미리보기 제스처 수용은 미검증입니다.
- `xcodebuild -project PictureFilterApp.xcodeproj -scheme PictureFilterApp -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath .build/DeviceDerivedData CODE_SIGNING_ALLOWED=NO -quiet build`: 성공. `.build/PF029-DeviceBuild.log`. 기존 전체 방향 지원 경고 1개. 설치·서명·실제 촬영 결과가 아닙니다.
- 남은 실기기 수용: 최소/최대/렌즈 경계에서 미리보기·저장 화각, 실제 렌즈 전환과 저조도 대체 렌즈 동작, 단일/복수 보유 기기의 배율과 전후면 복귀. 미보유 기기는 미검증입니다. PF-029는 이 조건 때문에 열린 상태를 유지합니다.

<a id="pf-030"></a>

## PF-030 촬영 중심 진입·재촬영 — 2026-10-02

- 최종 `.build/PF030-Regression.xcresult`: **단위 62개 + UI 4개 = 66개 통과**, 실패·건너뜀·런타임 경고 0개. iPhone 17 Pro / iOS 26.5. 로그 `.build/PF030-Regression.log`. simulator 프로필의 실기기 Vision/성능 9개는 실행하지 않았습니다.
- 실행: `bash scripts/test-ios.sh -only-testing:PictureFilterAppTests -only-testing:PictureFilterAppUITests/LaunchTests/testStartCameraWithoutSampleRetakeCompareAndSave -only-testing:PictureFilterAppUITests/LaunchTests/testStartLibraryWithoutSampleOpensPicker -only-testing:PictureFilterAppUITests/LaunchTests/testSampleSelectionChangeAndReturn -only-testing:PictureFilterAppUITests/LaunchTests/testDedicatedCameraCaptureAndCancelWithSimulatorStandIn -resultBundlePath .build/PF030-Regression.xcresult`.
- 샘플 없이 촬영 진입 → 3× 배율 대역 → 촬영 → 화사한 인물 기본 선택 → 세피아 선택 → 재촬영 후 세피아 유지 → 원본 비교 → 실제 시뮬레이터 Photos 저장 완료를 확인했습니다. 사진 선택 직접 진입의 시스템 picker 표시, 기존 샘플 왕복, 재촬영 취소 후 기존 사진·필터 유지도 확인했습니다.
- 모델은 첫 촬영 기본 필터, 재촬영 프리셋·강도·밝기·따뜻함 유지와 피부/조명/배경/인물별 초기화, 잘못된 촬영 데이터 및 교체 실패 시 이전 데이터/편집 보존, 정상 사진 교체 후 기본값 복귀를 검사했습니다.
- 촬영 데이터는 Debug 합성 대역입니다. 실제 카메라 미러링·방향·배율별 저장 구도는 미검증이며 PF-030의 실기기 수용 조건은 열린 상태로 남습니다.

<a id="pf-033"></a>

## PF-033 분석 상태·캐시 — 2026-10-02

- 최종 `.build/PF033-Final.xcresult`: **단위 65개 + UI 3개 = 68개 통과**, 실패·건너뜀·런타임 경고 0개. iPhone 17 Pro / iOS 26.5. `.build/PF033-Final.log`.
- 실행: `bash scripts/test-ios.sh -only-testing:PictureFilterAppTests -only-testing:PictureFilterAppUITests/LaunchTests/testPortraitControlKeepsOriginalWhenNoFaceIsDetected -only-testing:PictureFilterAppUITests/LaunchTests/testFailedFaceAnalysisIsDistinctAndOffersRetry -only-testing:PictureFilterAppUITests/LaunchTests/testStartCameraWithoutSampleRetakeCompareAndSave -resultBundlePath .build/PF033-Final.xcresult`. 실기기 Vision/반복 성능 9개는 미실행입니다.
- 캐시 검증: 동일 원본에서 피부+조명+배경의 강도 3개를 미리보기/출력 각 3회 처리했을 때 주입한 랜드마크·분할 호출은 각각 1회. 크기가 다른 출력도 동일 분석 사용. 사진 교체 후 이전 사진으로 돌아오면 다시 분석하여 원본 하나만 보관함을 검증. 실행 시간·시뮬레이터 열 상태를 테스트 첨부에 기록했으며 실제 기기 성능의 증거로 쓰지 않습니다.
- 실패 캐시/재시도: 실패를 0명 성공과 구분, 반복 입력 시 실패 재호출 억제, 명시적 재시도 후 재호출, 마스크 실패 시 원본 픽셀 보존과 실패 상태 보고를 검증했습니다.
- 모델: 분석 중 상태, 실패→재시도→0명 성공, 새 사진으로 교체한 뒤 늦게 도착한 이전 분석 결과 무시. UI는 명시적 대역으로 0명과 실패 안내를 각각 검사하고 촬영부터 저장까지 회귀 확인했습니다.
- 최초 실제 시뮬레이터 UI 검사는 0명 안내를 기대했으나 실제 추론 실패 안내가 나와 실패했습니다(`.build/PF033-UI.xcresult`). 이제 두 상태를 대역으로 분리하며 이 변경으로 시뮬레이터 추론을 성공으로 취급하지 않습니다.
- macOS 합성 피부 보정 보조 검사 통과(`.build/PF033-MacValidation.log`). 기기용 무서명 Debug 빌드 성공(`.build/PF033-DeviceBuild.log`). 설치·실제 카메라·기기 Vision 성능은 미검증입니다.
- 남은 수용: 실제 iPhone의 조합 효과 지연/메모리/열 상태 전후 비교와 피부·가림·모발·해상도별 시각 품질. 내부 QoS 경고는 이번 최종 결과에는 없지만 다른 환경에서도 해소됐다고 단정하지 않습니다.

<a id="pf-032"></a>

## PF-032 경계 보호·출력 일관성 — 2026-10-02

- `bash scripts/test-ios.sh -only-testing:PictureFilterAppTests -resultBundlePath .build/PF032-Final.xcresult`: **단위 68개 통과**, 실패·건너뜀·런타임 경고 0개. iPhone 17 Pro / iOS 26.5. `.build/PF032-Final.log`. 실기기 전용 9개는 미실행.
- 합성 마스크: 일반 페더링에서 눈 영역에 값이 새는 것을 먼저 확인하고 새 보호 마스크 적용 후 눈·입·윤곽 바깥 0, 피부 내부 240/255 초과를 검사했습니다. 실제 Vision 랜드마크 품질 검사는 아닙니다.
- 전경색 번짐: 빨간 전경/파란 배경의 경계에서 일반 흐림은 빨강 유출이 생기지만 새 배경 전용 계산은 배경 빨강 ≤1/255, 파랑 ≥254/255를 유지하며 전경 경계 안쪽 원본 픽셀은 정확히 일치했습니다. 강도 0의 원본 보존도 확인했습니다.
- 상대 강도: 1600px와 4096px 검정/흰색 경계의 대응 지점 7개가 채널 오차 3/255 이내이며 흐림이 실제 적용됐음을 함께 검사했습니다. 최초 반경 비례 방식은 한 지점에서 95/255 대 88/255로 실패했습니다(`PF032-Boundaries.xcresult`). 임계값을 늘리지 않고 공통 작업 해상도 계산으로 수정 후 통과했습니다.
- macOS 합성 얼굴 랜드마크 보조 검사 통과(`.build/PF032-MacValidation.log`): 얼굴 평균 변화 0.31531, 전체 흐림 4.83446, 보호 배경 최대 변화 0. 기기용 무서명 빌드 성공(`.build/PF032-DeviceBuild.log`). Core Image 커널 언어 API의 deprecated 경고가 남지만 컴파일 오류·테스트 실패는 없습니다.
- 미검증: 자연 사진의 모발·안경·가림·옆얼굴·다중 인물 경계 확대 리뷰, 실제 해상도별 주관적 효과 품질. 해당 수용은 사용자 실제 사진 평가가 필요하며 합성 검증으로 완료 처리하지 않습니다.

## 사용자 판단·실기기 제외 구현 범위 감사 — 2026-10-02

| 열린 작업 | 이번 범위에서 구현·자동 확인한 내용 | 별도 수용이 필요한 내용 |
| --- | --- | --- |
| PF-028 | 전용 촬영 서비스·상태·취소·원본 바이트 전달, 모델/대역 UI 회귀 | 실제 전후면·권한·초점·플래시·중단·구도 |
| PF-029 | 지원 범위·표시 배율·렌즈 경계·연속 조절·전환 초기화, 범위/경합 테스트 | 실제 렌즈 전환·화각·핀치 감각·기종별 수용 |
| PF-030 | 직접 촬영/사진 선택, 촬영 기본 필터, 재촬영 정책·교체 실패 보존, 저장까지 대역 UI | 실제 전면 미러링·회전·저장 구도 |
| PF-031 | 기존 수용 시나리오/기기 기록 기준 유지 | 실제 촬영·대표 사진·사용자 평가 전체 |
| PF-032 | 특징/윤곽 보호, 전경색 번짐 억제, 1600/4096 상대 강도, 합성 픽셀 검사 | 실제 가림·모발·옆얼굴·다중 인물 확대 리뷰 |
| PF-033 | 분석 상태/재시도/취소, 한 원본 캐시, 미리보기/출력 공통 좌표, 호출 수 검증 | 기기 지연·메모리·열 상태와 실제 품질 |
| PF-034 | 명시적 장치 선택, simulator/device 프로필, 미실행 보고, macOS 영역 보존 기준 | 실기기 Vision/카메라 실행 기록 |
| PF-035 | 기존 세부 품질 검증표 유지 | 대표 사진 선정·기준 확정·사용자 전후 비교 리뷰 |

전체 simulator 프로필 실행 `.build/Goal-FullSimulator.xcresult`는 **88개 중 87개 통과, 사진 권한 복구 UI 1개 실패**, 건너뜀·런타임 경고 0개였습니다. 실기기 전용 9개는 제외 목록으로 명시됐습니다. 제품 구현의 전체 단위 68개와 다른 UI 19개는 통과했으며, 권한 복구 테스트 수정은 별도 결과로 아래에 기록합니다. 장치 선택 회귀 8개·실행 프로필 회귀 4개·셸 문법·diff 공백 검사는 통과했습니다.

### PF-034 실제 Photos 권한 복구 수정 결과

`.build/PF034-Permission-Final.xcresult`: **1개 통과**, 실패·건너뜀·런타임 경고 0개. 실제 시뮬레이터 Photos 권한을 ‘안 함’으로 변경 → 일반 앱의 실제 Photos 서비스 저장 거부 확인 → ‘사진 추가만’ 복구 → 일반 앱 저장 성공을 확인했습니다. 로그 `.build/PF034-Permission-Final.log`.

실패 원인은 테스트의 환경/탐색 가정이었습니다. 대역만 실행하면 초기 권한 항목이 없을 수 있으므로 실제 권한을 먼저 요청합니다. 앱 설정 URL이 Settings 루트를 열 때는 남은 전역 검색창을 닫고 설치된 앱 목록으로 이동합니다. 복귀 시 이미 Photos 권한 페이지가 열려 있으면 앱 목록을 다시 찾지 않습니다. 권한 변경 후 실패하면 복구를 시도하며 복구 실패도 검사합니다. 중간 `PF034-AppSettings.xcresult`는 남은 검색창 때문에, `PF034-CleanSettings.xcresult`는 이미 열린 Photos 페이지를 인식하지 못해 실패했습니다. 최종 결과가 이전 권한 복구 미해결 기록을 대체합니다.

최종 자동 검증은 전체 회귀의 87개 통과 + 수정한 권한 복구 1개 집중 통과입니다. 하나의 결과 묶음에서 88개 모두 통과했다고 기록하지 않습니다. 추가 Python 회귀 12개, macOS 보조 검사, 기기용 무서명 컴파일 및 셸 문법/공백 검사도 통과했습니다. 실제 기기와 자연 사진 사용자 품질 판정은 수행하지 않았습니다. 남은 상위 PF 항목은 보류로 유지합니다.
