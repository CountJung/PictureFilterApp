# 프로젝트 구조

## 현재 존재하는 구성

```text
PictureFilterApp/
├─ README.md
├─ .gitignore
├─ project.yml                    # XcodeGen 프로젝트 정의
├─ PictureFilterApp.xcodeproj/    # 생성된 프로젝트·공유 스킴
├─ PictureFilterApp/
│  ├─ App/                       # 앱·기본 화면·서비스 주입
│  ├─ Features/Editor/           # 편집 모델·사진 변경·전용 카메라 시트
│  ├─ Features/Camera/           # 촬영 상태 모델·AVFoundation 미리보기
│  ├─ Models/                    # 필터 종류·편집 설정
│  ├─ Rendering/                 # Core Image 필터·화사한 인물·피부·조명·배경 흐림
│  ├─ Services/                  # 사진 입출력·직렬 큐 카메라 세션·실패 대역
│  └─ Resources/Samples/         # 가로·세로 색상표 PNG
├─ PictureFilterAppTests/         # 상태·렌더링·입출력·인물 효과 검증
├─ PictureFilterAppUITests/       # 편집·저장·접근성 UI 검증
├─ scripts/                       # 빌드·테스트·시뮬레이터 및 얼굴 보정 검증 자동화
├─ .vscode/tasks.json             # VS Code 작업 바로가기
└─ docs/                         # 기획·설계·작업·검증 문서
```

문서 역할은 [WORKFLOW](WORKFLOW.md), 진행 상태는 [TASKS](TASKS.md)를 참고합니다.

빌드 산출물과 테스트 결과는 `.build/` 아래에 두며 `.gitignore`에서 제외합니다. 자동화는 공유 스킴 `PictureFilterApp`을 사용하고 환경 변수로 시뮬레이터를 선택할 수 있습니다.

## 예정 구성

PF-028에서 전용 카메라 화면과 AVFoundation 촬영 서비스를 추가했습니다. 전용 배율 제어는 아직 없으며 PF-029에서 구현합니다. 예정 책임과 데이터 흐름은 [ARCHITECTURE](ARCHITECTURE.md#portrait-camera-next)를 따릅니다.

`Rendering/BrightPortraitFilter.swift`는 화사한 인물 톤 처리와 주입 가능한 얼굴 영역 검출을 담당합니다. `PictureFilterAppTests/BrightPortraitTests.swift`는 시뮬레이터에서 계조·피부색 범위·얼굴 영역·미리보기/출력 일치 및 원본 보존을 검증합니다.
