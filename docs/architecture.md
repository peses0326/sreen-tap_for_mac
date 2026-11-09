# 구조와 조사 범위

## 근거

- [AltTab 저장소](https://github.com/lwouis/alt-tab-macos): 기능과 프로젝트 개요. 공개 Swift 프로젝트라는 점에서 언어 교체만으로 메모리 문제를 해결할 수 있다고 가정하지 않았다.
- [원본 메모리 이슈 #5539](https://github.com/lwouis/alt-tab-macos/issues/5539): 개발자가 전체 크기 HiDPI 미리보기 보관 비용을 설명한다. 이 설명은 원본 설계의 비용에 관한 근거이며, 사용자의 700MB 전체를 이 요인 하나로 진단한 것은 아니다.
- [원본 WindowServer 이슈 #4255](https://github.com/lwouis/alt-tab-macos/issues/4255): 원본 프로세스 외 WindowServer 비용도 관찰해야 한다는 근거.
- [Apple SCScreenshotManager](https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager): 일회성 창 이미지 요청.
- [Apple AXUIElement](https://developer.apple.com/documentation/applicationservices/axuielement): 창 열거와 접근성 동작.
- 설치된 macOS SDK의 ScreenCaptureKit 헤더에서 출력 픽셀 크기, 독립 창 필터, 그림자 제외 설정을 확인했다.

터미널의 GitHub 접근이 DNS 제한으로 실패하여 원본 전체 저장소를 내려받지 못했다. 웹에서 확인한 개요·공개 이슈를 근거로 구현했으며, 원본 전체 소스의 정적 분석이나 원본 메모리 프로파일링은 완료하지 않았다. 원본 Swift 코드를 복사하지 않았다.

## 책임 분리

| 구성 요소 | 책임 |
|---|---|
| `ScreenTapCore/WindowOrder.swift` | 창별 MRU, 선택 인덱스, 엄격한 바이트 예산 캐시, 캡처 작업 제한 |
| `WindowService.swift` | 직렬 큐에서 AX 창 열거·활성화·포커스 추적 |
| `ThumbnailService.swift` | 현재 페이지의 저해상도 이미지만 순차 캡처 |
| `SwitcherView.swift` | 하나의 AppKit 뷰로 이미지 격자 그리기 |
| `HotKey.swift` | Option-Tab, 키 반복, Option 해제 감지 |
| `AppController.swift` | 메뉴, 권한 안내, 화면 세션, 페이지 이동 |
| `MemoryDiagnostics.swift` | 자기 프로세스의 `phys_footprint` 측정 |

AX 호출은 다른 프로세스가 응답해야 하므로 직렬 백그라운드 큐에서 처리하며 메시징 제한 시간을 설정한다. UI 선택 이동은 메인 스레드에서 처리한다. 전환기를 숨긴 다음 runloop에서 활성화를 요청해 AX 응답 지연이 화면 숨김을 막지 않도록 한다.

## 이미지 수명

1. 전환기를 열면 창 메타데이터를 읽고 현재 페이지를 그린다.
2. ScreenCaptureKit에서 현재 페이지의 SCWindow만 남긴다.
3. 한 창씩 최대 480×300픽셀 SDR 이미지를 요청한다. macOS 26에서는 전용 SCScreenshotConfiguration을 사용하고 실패하면 이전 API로 재시도한다.
4. OS 반환 이미지의 실제 크기로 축소 비율을 다시 계산한다. 작은 CGContext로 복사해 캡처 표면과 캐시의 참조를 분리하며 요청보다 큰 이미지를 버리지 않는다.
5. `bytesPerRow × height`로 실제 픽셀 비용을 계산해 캐시에 넣는다.
6. 페이지 이동은 이전 결과의 세대를 무효화한다. 진행 중 요청이 돌아오기 전에는 새 요청을 시작하지 않는다.
7. 닫기와 메모리 압력에서 캐시를 비우며 패널은 닫기 때 함께 해제한다.

캡처 API가 응답하지 않으면 슬롯을 계속 점유한다. 이때 무제한 새 요청을 쌓지 않으며 아이콘을 사용한 창 선택은 가능하다. 강제로 ScreenCaptureKit 내부 요청을 취소하는 API는 사용하지 않는다.

12MiB 상한은 캐시 픽셀 소유권에만 적용된다. OS 내부 표면, 캡처 시 임시 복사, UI 렌더링 버퍼, 아이콘 시스템 캐시, AX 객체 등의 비용까지 제한한다고 주장하지 않는다.

## 주요 차이

원본의 전체 크기 선택 창 미리보기를 구현하지 않고 작은 격자 미리보기만 제공한다. 검색·다국어 리소스 축소보다 이미지 해상도·개수·수명과 캡처 동시성에 우선순위를 두었다. 앱 전체 메모리 목표는 실사용 측정으로 정해야 하며 0.1.1의 종료 후 43.1MiB, 마지막 캡처 시점 134.8MiB는 초기 참고 측정이며 0.2.0의 성능 보증으로 사용하지 않는다.

## 0.2.0 브랜드와 공개용 렌더링

앱 이름은 ScreenTap으로 변경했다. 프로덕션 `SwitcherView`와 공개용 이미지 생성 도구는 `ScreenTapCore/SwitcherRenderer.swift`를 공유한다. 이미지 생성 도구는 별도 실행 타깃이므로 앱 실행 중에는 로드되지 않는다. 데모 창 콘텐츠는 도구가 자체 생성하며, 사용자의 실제 창이나 메시지를 공개 이미지에 포함하지 않는다.

번들 식별자는 `local.espark.LeanTab`을 유지해 불필요한 앱 신원 변경을 피한다. ad-hoc 서명의 코드 변경이나 앱 경로 변경으로 인한 TCC 재승인 가능성까지 없어진다고 보장하지는 않는다.
