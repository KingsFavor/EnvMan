<div align="center">
  <h1>EnvMan</h1>
  <p><b>환경변수를 암호화해서 로컬에 보관하고, 필요할 때 한 번에 복사하는 macOS 앱</b></p>
  <p><i>A local, encrypted environment variable manager for macOS.</i></p>
</div>

---

## 무엇을 하나요

- **네임스페이스로 정리** 프로젝트와 환경 단위(예: `my-api / production`)로 키와 값을 묶어 둡니다.
- **암호화 보관** 값은 AES-256-GCM으로 암호화되어 디스크에 평문으로 남지 않습니다. 비밀번호 없이도 목록(네임스페이스와 키 이름)은 볼 수 있고, 값을 보거나 복사할 때만 잠금을 해제합니다.
- **빠른 복사** 키 목록에서 원하는 항목만 골라 `.env`, `shell`, `JSON`, `gh secret set` 형식으로 한 번에 복사합니다. 복사한 값은 설정한 시간 뒤 클립보드에서 자동으로 지워집니다.
- **암호화 공유** 선택한 네임스페이스를 공유 암호로 묶은 `.envman` 파일로 내보내고, 받는 쪽은 그 암호로 열어 자신의 비밀번호로 다시 암호화해 가져옵니다.
- **메뉴바 중심** Dock 없이 메뉴바에서 바로 해제하고 복사합니다.

가볍고 네이티브입니다. **SwiftUI만** 사용하고, 모든 데이터는 **로컬**에만 저장됩니다.

## 보안 모델

두 계층으로 나뉩니다.

- **기기 키 계층** macOS Keychain에 보관되는 기기 전용 키가 네임스페이스와 키 이름 등 메타데이터를 암호화합니다. 앱이 자동으로 접근하므로 비밀번호 없이 목록을 볼 수 있고, 디스크에는 평문이 없습니다.
- **마스터 비밀번호 계층** 비밀번호를 PBKDF2로 늘려 KEK를 만들고, KEK로 데이터 키(DEK)를 감싸 저장합니다. 값은 DEK와 AES-256-GCM으로 암호화합니다. 비밀번호, KEK, DEK는 디스크에 저장하지 않고 해제된 세션 동안 메모리에만 둡니다.

비밀번호를 잊으면 값은 복구할 수 없습니다.

## 요구 사항

- macOS 14 (Sonoma) 이상

## 설치 (Homebrew)

```bash
brew install --cask kingsfavor/tap/envman
```

## 업데이트

```bash
brew update && brew upgrade --cask envman
```

Homebrew로 설치하지 않았다면 [Releases](https://github.com/KingsFavor/EnvMan/releases)에서 최신 `EnvMan-x.y.z.dmg`를 받아 `/Applications`의 앱을 덮어쓰세요.

## 빌드

```bash
xcodebuild build -project EnvMan.xcodeproj -scheme EnvMan \
  -configuration Debug -destination "generic/platform=macOS" \
  CODE_SIGNING_ALLOWED=NO
```

## 구조

```
EnvMan/
  App/       진입점, 메뉴바 및 관리자 창, 활성화 정책
  Design/    Theme(팔레트와 모양), Color+Hex
  Models/    Vault, Namespace, Secret, 포맷 헬퍼
  Crypto/    AES-GCM와 PBKDF2, Keychain 기기 키
  Store/     VaultStore(암호화 영속, 세션, CRUD, 내보내기와 가져오기)
  System/    설정, 클립보드 자동 삭제, 복사 형식, 공유 번들, 업데이트 확인
  Views/     메뉴바, 관리자, 시크릿 목록, 편집기, 공유 시트, 설정
```

배포는 태그(`vX.Y.Z`) 푸시로 `release.yml`이 공증 DMG를 만들고 `KingsFavor/homebrew-tap`의 cask를 갱신합니다.
