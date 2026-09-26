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

## PF-019 실기기 품질·성능 검증 — 완료

12MP 합성 색상표(`4032×3024`)를 테스트 전용 리소스로 추가했습니다. 원본 크기와 12개 색상 패치의 RGB 평균, 미리보기 및 JPEG 원본 크기 출력 40회 반복을 실기기에서 확인했습니다.

- iPhone 16 Pro Max (iOS 26.6.2): 전체 단위 테스트 31개 통과, 결과 `.build/PF019-Device-FinalSuite.xcresult`.
- JPEG 출력 크기 `4032×3024`; 12개 색상 패치 평균은 각 RGB 채널 기준 목표값 ±12 이내.
- 40회 미리보기(1600px) + 원본 크기 JPEG 출력 반복: 평균 `183.0 ms`, 중앙값 `183.2 ms`, 최대 `185.8 ms`. 열 상태는 10회 간격 표본 및 종료 시 모두 `nominal`.
- 검증은 합성 색상표를 이용한 짧은 반복 부하입니다. 60회 탐색 실행 하나는 signal kill로 끝났으나 원인은 확인되지 않았습니다. 따라서 장시간 발열, 메모리 한계, 자연 사진에서의 주관적 색감 품질은 검증 완료로 간주하지 않습니다. 출시 전 실제 사진 및 장시간 부하 검증이 필요해지면 별도 작업으로 등록합니다.
