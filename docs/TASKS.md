# 열린 작업 목록

이 문서는 진행할 일만 표시합니다. `[ ]`는 열린 상태이며, 완료·취소된 항목의 상세와 변경 이력은 [완료 항목 보관소](TASKS_ARCHIVE.md)에 있습니다. PF 번호는 생성 후 바꾸거나 재사용하지 않습니다. 관리 규칙은 [WORKFLOW](WORKFLOW.md)를 따릅니다.

## 다음 작업

### 인물 보정

<a id="pf-024"></a>

- [ ] **PF-024 · 인물별 선택형 자연 보정**

  **상태: 미착수** · 우선순위: P1

  - **할 일 / 완료 조건:** 여러 인물 중 대상을 고르고 피부를 선택 보정하며, 눈·입·머리카락과 피부 질감을 보존하고 보정 일부를 되돌리는 흐름 구현
  - **선행 작업:** [PF-023](TASKS_ARCHIVE.md#pf-023)
  - **참고 자료:** [Adobe 인물 마스킹 및 잡티 보정](https://helpx.adobe.com/uk/lightroom/web/edit-photos/apply-masks/mask-with-ai.html), [Adobe Lightroom 모바일 인물 잡티 보정](https://helpx.adobe.com/lightroom/mobile/apply-quick-actions/remove-blemishes-using-quick-actions.html)
  - **설계 문서:** [ARCHITECTURE](ARCHITECTURE.md), [DECISIONS](DECISIONS.md), [E2E](E2E.md)
  - **담당 / 갱신일:** — / 2026-09-26
  - **완료 조건:** 인물별 적용 여부·강도 조절·원본 비교·초기화 및 마스크 실패 시 원본 보존을 테스트하고, 합성 테스트와 실제 인물 사진에서 경계와 질감 보존을 확인. 얼굴형 변경이나 과도한 미백은 범위에서 제외.

### 후속 후보

<a id="pf-025"></a>

- [ ] **PF-025 · 인물 조명과 배경 깊이 효과**

  **상태: 미착수** · 우선순위: P2

  - **할 일 / 완료 조건:** 사용자가 고른 인물에 조명을 조절하고, 촬영 후 사진에서도 배경 흐림을 켜고 강도를 바꾸는 경험을 설계·구현
  - **선행 작업:** [PF-024](#pf-024)
  - **참고 자료:** [Apple 인물 조명·심도](https://support.apple.com/guide/iphone/take-portraits-iphd7d3a91a2/27/ios/27), [Google Photos Portrait Light·Blur](https://blog.google/products-and-platforms/products/photos/google-ai-photo-editing-features-tips/)
  - **설계 문서:** [MASTER_PLAN](MASTER_PLAN.md), [ARCHITECTURE](ARCHITECTURE.md), [DECISIONS](DECISIONS.md)
  - **담당 / 갱신일:** — / 2026-09-26
  - **완료 조건:** 초점 대상 선택, 배경 마스크 경계·강도·원본 복구를 확인하고 깊이 정보가 없는 사진의 로컬 분할 대안을 검증. 현재 범위에서 제외했던 후속 기능.

## 변경 기록

- 2026-09-26 · PF-001~PF-017, PF-020~PF-021의 완료 항목과 전체 진행 이력을 [TASKS_ARCHIVE](TASKS_ARCHIVE.md)로 이동. 열린 항목만 이 문서에 남김.
- 2026-09-26 · PF-022~PF-025: 제품 방향과 첫 네 스타일을 확정하고, 인물별 보정을 구현 항목으로 남김. 공개 제품에서 확인한 인물 조명·배경 흐림은 별도 후속 작업으로 분리.
