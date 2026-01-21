# Monad Standard Flake Templates

Monad 팀의 개발 환경을 표준화하기 위한 `flake.nix` 템플릿 레포지토리입니다.

이 레포지토리는 프로젝트 분야별(Web / Backend / App / Infra 등)로 공통 개발 환경을 제공하며,
모든 팀원이 동일한 도구/버전/의존성으로 개발할 수 있도록 설계되었습니다.

---

## 1. 목적

본 레포지토리는 다음 목표를 가집니다.

- 팀 전체 개발 환경의 표준화
- "내 컴퓨터에서는 되는데" 문제 제거
- 프로젝트별 의존성 차이 최소화
- CI(GitHub Actions)와 로컬 개발환경 일치
- 배포 환경과 개발 환경 정합성 강화

---

## 2. 기본 원칙

- 모든 신규 프로젝트는 이 레포의 템플릿 중 하나를 기반으로 생성하는 것을 원칙으로 합니다.
- 모든 프로젝트는 Nix 기반 빌드/실행이 가능해야 합니다.
- CI에서는 Nix 기반 빌드가 존재해야 하며, Actions 성공을 merge 기준으로 삼습니다.
- 포맷팅(Formatting) 체크 실패 시 merge는 불가합니다.

---

## 3. 디렉토리 구조(예시)

이 레포는 아래와 같은 형태로 템플릿을 관리합니다.

- `templates/`
  - `web/`
    - `flake.nix`
    - `README.md`
  - `backend/`
    - `flake.nix`
    - `README.md`
  - `app/`
    - `flake.nix`
    - `README.md`
  - `infra/`
    - `flake.nix`
    - `README.md`
- `modules/`
  - 공통 모듈(devShell, formatter, lint 등)을 재사용 가능한 형태로 관리
- `.github/workflows/`
  - 템플릿 검증 및 CI 실행

실제 구조는 팀 운영 방식에 맞게 확장 가능합니다.

---

## 4. 포함되는 표준 구성

템플릿은 아래 요소들을 포함하는 것을 목표로 합니다.

- `devShell` 제공 (개발용 쉘 환경)
- 팀에서 사용하는 표준 도구 제공
  - formatter
  - linter
  - build toolchain
  - language runtime (Node / Python / Rust 등)
- `nix flake check` 지원
- CI에서 그대로 사용 가능한 구성

---

## 5. 사용 방법

### 5.1 빠른 진입(devShell)

프로젝트 루트에 `flake.nix`가 존재한다면 아래로 개발 환경 진입이 가능합니다.

[Nix 다운로드하기!](https://nixos.org/download/)

```bash
nix develop
```

성공하면 프로젝트에서 요구하는 표준 도구들이 PATH에 포함된 상태로 쉘이 열립니다.

---

5.2 빌드

프로젝트에서 packages를 제공하는 경우 아래처럼 빌드할 수 있습니다.

nix build

또는 특정 패키지를 지정하는 구조라면:

nix build .#<package-name>


---

5.3 체크(CI와 동일 기준)

CI와 동일한 기준으로 검증하려면 다음을 사용합니다.

nix flake check


---

6. 템플릿 적용 규칙(팀 운영 기준)
	•	프로젝트는 분야별 표준 템플릿(web, backend, app 등) 중 하나를 기반으로 구성합니다.
	•	개인 환경에서만 돌아가는 의존성 추가는 금지합니다.
	•	모든 팀원은 동일한 템플릿 기반 환경에서 개발해야 합니다.
	•	CI에서 Nix 빌드 및 포맷 검사가 통과하지 못하면 main 반영 불가입니다.

---

7. GitHub Actions(권장)

모든 프로젝트는 아래 검증 단계를 포함해야 합니다.
	•	Nix 기반 build/check
	•	formatting 검사
	•	(가능하면) test

예시 흐름
	•	nix flake check
	•	nix build
	•	formatter check (프로젝트별로 상이)

---

8. 기여(Contributing)

템플릿 변경은 전체 프로젝트에 영향을 줄 수 있으므로,
아래 규칙을 따릅니다.
	•	변경 사항은 반드시 PR로 반영합니다.
	•	PR에는 변경 이유와 영향을 명확히 작성합니다.
	•	템플릿 수정 시 최소 1개 이상의 실제 프로젝트 적용 가능성을 확인합니다.
	•	CI에서 검증이 통과해야 merge 가능합니다.

---

9. 버전 정책
	•	템플릿은 가능한 한 안정적인 버전을 유지합니다.
	•	큰 변경(언어 버전 업, 빌드 구조 변경 등)은 사전에 공지하고 적용합니다.
	•	업데이트로 인해 팀 프로젝트가 깨질 수 있는 변경은 즉시 반영하지 않습니다.

---

10. 문의 및 공지 채널
	•	표준 템플릿 공지: Discord (Monad 공지 채널)
	•	템플릿 관련 문서: Notion (표준 개발 환경 문서)
	•	규칙/정책 관련 문의: 관리자 또는 운영진

---

License

This repository is intended for internal team usage.
(라이선스 정책은 팀 운영 방식에 따라 추후 명시합니다.)