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
│  ├─ Features/Editor/           # 편집 모델·미리보기·사진 변경·카메라 촬영 화면
│  ├─ Models/                    # 필터 종류·편집 설정
│  ├─ Rendering/                 # Core Image 필터·피부·인물 조명·배경 흐림
│  ├─ Services/                  # 샘플 입력·메모리 출력·실패 대역
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

전용 카메라 화면과 AVFoundation 촬영 서비스는 PF-028에서 추가합니다. 현재 Features/Editor/CameraCaptureSheet.swift는 시스템 카메라 피커 연결이며 전용 줌 제어 구현이 아닙니다. 예정 책임과 데이터 흐름은 [ARCHITECTURE](ARCHITECTURE.md#portrait-camera-next)를 따릅니다.
