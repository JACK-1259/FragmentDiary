# 조각일기 1.0 출시 체크리스트

✅ = 코드에서 이미 끝낸 것 · ☐ = 직접 해야 하는 것

## A. 코드 정리 (끝남)

- ✅ 디버그 전용 기능 삭제: 시뮬레이터 잠금 건너뛰기, 샘플 기록 채우기/지우기, 위젯 미리보기, 샘플 일정·사진 시더
- ✅ 테스트로 채운 샘플 일기 자동 정리: 업데이트 후 첫 잠금 해제 때 샘플로 넣은 날만 지워져요(직접 쓴 기록은 그대로)
- ✅ "함께" 탭과 설정의 폴더 이름 항목 숨김 (`ReleaseFeatures.sharedFolders = false`). 동기화를 붙이는 버전에서 `true`로
- ✅ 열쇠가 없을 때 갇히지 않게: 잠금 화면에 "새 일기장으로 시작하기" (열 수 없는 파일은 지우지 않고 `Unreadable <날짜>` 폴더로 옮김)
- ✅ 잠금을 꺼 둔 상태에서도 "열기" 버튼이 보이게
- ✅ 개인정보 명세(PrivacyInfo.xcprivacy) — 앱·위젯
- ✅ 버전 1.0 (빌드 1)
- ✅ 설정에 백업 안내 문구: "iCloud 백업이나 암호화된 컴퓨터 백업에서 복원하면 기록도 함께 돌아와요"
- ✅ Release 빌드 확인: 디버그 기능이 빠진 채로 빌드됨

## B. 개발자 계정 가입 후

- ☐ Apple Developer Program 가입 (연 $99 / 개인)
- ☐ Xcode › Signing & Capabilities 에서 팀을 새 유료 팀으로 변경 (앱·위젯 둘 다)
- ☐ App Groups `group.com.jonghwa.fragmentdiary` 켜기 (앱·위젯 둘 다) → 실제 폰에서 위젯 숫자가 나오는지 확인
- ☐ 기기 빌드 명령에서 `CODE_SIGN_ENTITLEMENTS=` 빼기 (무료 팀 때문에 넣었던 임시 옵션)
- ☐ **내 폰의 테스트 앱 삭제 후 설치**: 팀이 바뀌면 키체인 그룹이 달라져 기존 테스트 일기를 열 수 없어요. 지우고 깨끗하게 설치하거나, 잠금 화면의 "새 일기장으로 시작하기"를 누르면 돼요. (필요한 기록은 미리 "텍스트로 내보내기")

## C. App Store Connect

- ☐ 새 앱 만들기: 이름 "조각일기", 번들 ID `com.jonghwa.fragmentdiary`, SKU `fragmentdiary-ios`
- ☐ 개인정보 처리방침 URL 등록
  - 저장소 GitHub › Settings › Pages › Branch: `main`, 폴더: `/docs` → 저장
  - 주소: `https://jack-1259.github.io/FragmentDiary/privacy-policy.html`
  - `docs/privacy-policy.html`의 `[문의 이메일]`을 실제 연락처로 바꾸기
- ☐ 지원 URL (저장소 주소나 간단한 페이지)
- ☐ 앱 개인정보: "데이터를 수집하지 않음"
- ☐ 연령 등급 질문 (예상 4+)
- ☐ 수출 규정(암호화) 질문 답변 — `docs/appstore-listing.md` 참고
- ☐ 설명·키워드·부제·프로모션 문구 — `docs/appstore-listing.md`에서 붙여 넣기
- ✅ 스크린샷 준비됨: `docs/appstore-screenshots/` (iPhone 6.9″ 1320×2868 6장, iPad 13″ 2064×2752 2장) → 순서대로 올리기
- ☐ 앱 아이콘 1024px (에셋에 있음 — 업로드 시 자동 사용)

## D. TestFlight로 1–2주 써보기 (출시 전 꼭)

- ☐ 업데이트 설치 후에도 기록이 그대로 열리는지 (빌드 번호만 올려 두 번 설치)
- ☐ 저녁 알림이 제시간에 오고, 누르면 질문 카드가 열리는지
- ☐ 위젯(홈·잠금 화면) 숫자 갱신
- ☐ **백업 복원 시나리오**: iCloud 백업 → 다른 기기(또는 초기화 후)로 복원 → 기록이 열리는지. 설정 문구가 약속하는 내용이라 꼭 확인
- ☐ iPad 가로 화면·Split View(화면 나눠 쓰기)에서 오늘·기록·그림 화면 확인 (시뮬레이터에서 회전을 못 해봤어요)
- ☐ 권한을 모두 거부한 상태로 처음부터 써보기 (심사관이 자주 하는 경로)
- ☐ 다크 모드, 큰 글씨(설정 › 손쉬운 사용 › 더 큰 텍스트)

## E. 제출

- ☐ Xcode › Product › Archive → Distribute App → App Store Connect
- ☐ 빌드 선택, 심사 메모 붙여 넣기, "수동 출시"로 두고 제출
- ☐ 승인되면 원하는 날 출시

## F. 1.1 이후 (계정 생긴 뒤)

- iCloud 동기화(개인) + "함께" 폴더(CloudKit 공유) → `ReleaseFeatures.sharedFolders = true`
- 구독(StoreKit): 동기화·함께를 유료로
- 영어 지원
