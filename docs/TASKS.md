# 열린 작업 목록

이 문서는 진행할 일만 표시합니다. `[ ]`는 열린 상태이며, 완료·취소된 항목의 상세와 변경 이력은 [완료 항목 보관소](TASKS_ARCHIVE.md)에 있습니다. PF 번호는 생성 후 바꾸거나 재사용하지 않습니다. 관리 규칙은 [WORKFLOW](WORKFLOW.md)를 따릅니다.

## 다음 작업

### 제품 방향

<a id="pf-022"></a>

- [ ] **PF-022 · 사진 스타일·인물 보정 방향 정리**

  **상태: 진행 중** · 우선순위: P1

  - **할 일 / 완료 조건:** 사용자가 이 앱으로 어떤 분위기와 이야기를 사진에 담고 싶은지 정리하고, 차별화된 첫 필터 묶음과 제외 범위를 결정
  - **참고 자료:** [Adobe Lightroom 프리셋](https://helpx.adobe.com/lightroom/desktop/edit-photos/presets.html), [Adobe 인물 마스킹](https://helpx.adobe.com/uk/lightroom/web/edit-photos/apply-masks/mask-with-ai.html), [Apple 인물 사진 조명·심도](https://support.apple.com/guide/iphone/take-portraits-iphd7d3a91a2/27/ios/27), [Google Photos 인물 조명·흐림·강도 조절](https://blog.google/products-and-platforms/products/photos/google-ai-photo-editing-features-tips/)
  - **설계 문서:** [MASTER_PLAN](MASTER_PLAN.md), [DECISIONS](DECISIONS.md)
  - **담당 / 갱신일:** Codex / 2026-09-26
  - **조사 결과:** 공개 공식 자료에서 Lightroom은 인물 프리셋과 필름 영감 룩, 사람별 피부·눈·입술·치아·머리카락 마스크, 잡티 보정의 강도·복원 조절을 제공합니다. Apple Photos와 Google Photos는 촬영 후 인물 조명, 배경 흐림, 효과 강도 조절을 안내합니다. 현재 앱은 전역 흑백·세피아·따뜻함·차가움 필터와 눈·입을 제외한 단순 얼굴 피부 부드럽게 하기를 제공하며, 개인별 선택·세부 얼굴 영역 보정·인물 조명은 아직 없습니다.
  - **아이디어 초안:** (1) 색온도만 바꾸지 않는 3~5개 사진 스타일 프리셋: 필름 질감/톤, 인물에 어울리는 자연광, 도시 야간 등. (2) 인물별 피부 보정과 선택 영역 복원으로 피부 질감·눈·입·머리카락을 보존. (3) 후속 후보로 인물 조명과 배경 흐림. 프리셋 즐겨찾기와 빠른 전후 비교도 검토합니다. 이는 공개 제품 동작에서 얻은 아이디어이며, 사용자 가치와 첫 출시 범위는 아직 결정하지 않았습니다.

<a id="pf-023"></a>

- [ ] **PF-023 · 개성 있는 첫 사진 스타일 필터 묶음 구현**

  **상태: 미착수** · 우선순위: P1

  - **할 일 / 완료 조건:** PF-022에서 고른 3~5개 스타일을 기존 강도·원본 비교 흐름에 연결하고, 대표 인물·풍경 사진에서 스타일 차이와 자연스러움을 확인
  - **선행 작업:** [PF-022](#pf-022)
  - **설계 문서:** [MASTER_PLAN](MASTER_PLAN.md), [ARCHITECTURE](ARCHITECTURE.md), [DECISIONS](DECISIONS.md)
  - **담당 / 갱신일:** — / 2026-09-26
  - **아이디어 후보:** 필름 영감 톤, 자연광 인물, 도시 야간 등. 실제 스타일과 렌더 조합은 PF-022에서 결정합니다.

<a id="pf-024"></a>

- [ ] **PF-024 · 인물별 선택형 자연 보정**

  **상태: 미착수** · 우선순위: P1

  - **할 일 / 완료 조건:** 여러 인물 중 대상을 고르고 피부를 선택 보정하며, 눈·입·머리카락과 피부 질감을 보존하고 보정 일부를 되돌리는 흐름 구현
  - **선행 작업:** [PF-022](#pf-022)
  - **참고 자료:** [Adobe 인물 마스킹 및 잡티 보정](https://helpx.adobe.com/uk/lightroom/web/edit-photos/apply-masks/mask-with-ai.html), [Adobe Lightroom 모바일 인물 잡티 보정](https://helpx.adobe.com/lightroom/mobile/apply-quick-actions/remove-blemishes-using-quick-actions.html)
  - **설계 문서:** [ARCHITECTURE](ARCHITECTURE.md), [DECISIONS](DECISIONS.md), [E2E](E2E.md)
  - **담당 / 갱신일:** — / 2026-09-26
  - **완료 조건:** 인물별 적용 여부·강도 조절·원본 비교·초기화 및 마스크 실패 시 원본 보존을 테스트하고, 합성 테스트와 실제 인물 사진에서 경계와 질감 보존을 확인. 얼굴형 변경이나 과도한 미백은 범위에서 제외.

## 변경 기록

- 2026-09-26 · PF-001~PF-017, PF-020~PF-021의 완료 항목과 전체 진행 이력을 [TASKS_ARCHIVE](TASKS_ARCHIVE.md)로 이동. 열린 항목만 이 문서에 남김.
- 2026-09-26 · PF-022~PF-024: 공개 공식 자료에서 필름 스타일 프리셋, 얼굴 영역별 보정, 인물 조명·배경 흐림 기능을 조사해 제품 방향·첫 스타일 묶음·인물별 자연 보정 작업으로 분리.
