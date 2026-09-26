# 열린 작업 목록

이 문서는 진행할 일만 표시합니다. `[ ]`는 열린 상태이며, 완료·취소된 항목의 상세와 변경 이력은 [완료 항목 보관소](TASKS_ARCHIVE.md)에 있습니다. PF 번호는 생성 후 바꾸거나 재사용하지 않습니다. 관리 규칙은 [WORKFLOW](WORKFLOW.md)를 따릅니다.

## 다음 작업

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
- 2026-09-26 · PF-024 조사 보강: 사람별 보정·복원·초기화와 피부 질감 조절 자료, Apple Vision 개별 인물 마스크를 확인. 조사 결과와 적용 범위는 [DECISIONS](DECISIONS.md)에 기록.
- 2026-09-26 · PF-024 완료: 인물별 보정·부분 초기화와 마스크 보호, 기기 테스트 및 CC0 실제 인물 사진 리뷰 완료. 상세·근거는 [보관소](TASKS_ARCHIVE.md#pf-024), [E2E](E2E.md#pf-024-인물별-자연-보정-검증)에 기록.
