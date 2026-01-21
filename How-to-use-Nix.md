# Monad Nix Guide (Flake + 사용법 빠른 정리)

이 문서는 Monad 동아리원이 팀 표준 개발환경(Nix + Flakes)을 빠르게 익히고,
프로젝트에서 동일한 환경으로 개발할 수 있도록 만든 가이드입니다.

---

## 0. 왜 Nix를 쓰는가?

Nix를 쓰는 이유는 간단합니다.

- 팀원 모두 같은 버전/같은 도구로 개발 가능
- "내 PC에서는 됨" 문제 감소
- CI(GitHub Actions)와 로컬 환경을 일치시키기 쉬움
- 프로젝트별 개발 환경을 깔끔하게 분리 가능

---

## 1. 꼭 알아야 하는 핵심 개념

### 1.1 Nix가 제공하는 것
- 패키지 설치(일회성 설치 가능)
- 개발 환경(devShell) 제공
- 빌드/검증 자동화 가능

### 1.2 Flake란?
Flake는 "프로젝트 단위로 개발환경을 고정"하기 위한 구조입니다.

Flake가 있으면:
- 누가 실행하든 같은 개발환경이 열림
- CI에서 동일한 방식으로 검증 가능

프로젝트 루트에 `flake.nix`가 있으면, 그 프로젝트는 Nix 기준으로 운영됩니다.

---

## 2. 기본 사용법(자주 쓰는 명령어)

### 2.1 개발환경 들어가기
프로젝트 루트에서:

```bash
nix develop
```

이제 이 쉘 안에서만 필요한 도구가 준비됩니다.
(밖으로 나가면 시스템 환경은 그대로 유지됨)

---

2.2 프로젝트 체크(검증)

CI와 동일한 기준으로 검증:

```bash
nix flake check
```

	•	실패하면 main 반영 불가
	•	템플릿 레포는 이 명령이 통과되는 것을 기준으로 관리함

---

2.3 빌드(패키지 정의가 있다면)

```bash
nix build
```

또는 특정 패키지 이름이 존재한다면:

```bash
nix build .#<패키지이름>
```

---

2.4 포맷(가능한 프로젝트는)

```bash
nix fmt
```

---

2.5 임시로 패키지 한 번만 쓰기

설치 없이 바로 실행:

```bash
nix run nixpkgs#htop
```

---

2.6 임시로 도구만 잠깐 추가해서 쉘 열기

```bash
nix shell nixpkgs#jq nixpkgs#curl
```

---

3. Flake 구조(읽는 방법)

기본적인 flake.nix 구조는 아래처럼 생겼습니다.
```nix
{
  description = "Project description";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            git
            curl
          ];
        };
      }
    );
}
```

---

4. Flake 작성법(동아리 표준 템플릿 방식)

4.1 최소 devShell 템플릿(제일 기본)

아래 형태만 있어도 “표준 개발환경”이 됩니다.
```nix
{
  description = "Monad devShell (minimal)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            git
            curl
            jq
            ripgrep
          ];
        };
      }
    );
}
```

---

4.2 Node/React 개발환경 예시
```nix
{
  description = "Monad devShell: react";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        node = pkgs.nodejs_20;
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            node
            nodePackages.pnpm
            nodePackages.prettier
            nodePackages.eslint
            nodePackages.typescript
          ];
        };
      }
    );
}
```

---

4.3 Rust 개발환경 예시

```nix
{
  description = "Monad devShell: rust";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            cargo
            rustc
            rustfmt
            clippy
          ];

          RUST_BACKTRACE = "1";
        };
      }
    );
}
```

---

5. CI 기준(중요)

Monad 규칙상:
	•	GitHub Actions에서 Nix 기반 빌드/검증이 존재해야 함
	•	Actions 성공이 merge 기준임
	•	formatting 체크 실패 시 merge 불가

즉, 개발자는 로컬에서 최소 다음은 통과시키고 PR을 올려야 합니다.

```bash
nix flake check
```

---

6. 팀 규칙(중요)
	•	main 브랜치에 직접 push/commit 금지
	•	PR 기반으로만 반영
	•	Approve 규칙을 충족해야 merge 가능
	•	main은 항상 배포 가능한 상태 유지
	•	개발환경은 Nix 기반으로 통일

---

7. 자주 터지는 문제와 해결

7.1 nix develop이 너무 오래 걸림

처음은 다운로드 때문에 느릴 수 있습니다.
두 번째부터는 캐시로 빨라집니다.

---

7.2 “experimental-features” 관련 에러

Flakes 기능이 꺼져있으면 발생합니다.

해결 방법(임시):
```bash
nix --extra-experimental-features "nix-command flakes" develop
```

---

7.3 패키지가 없다고 나옴

nixpkgs 버전/패키지명이 바뀌었을 수 있습니다.
	•	패키지 이름 확인 -> [Nix Packages](https://search.nixos.org/packages?channel=25.11)
	•	관리자 또는 템플릿 담당자에게 문의

---

8. 최소 실전 루틴(권장)

프로젝트 시작 루틴

```bash
git clone <repo>
cd <repo>
nix develop
```
PR 올리기 전 체크

```bash
nix flake check
```

---

9. 문의 / 운영
	•	표준 flake 템플릿 레포를 우선 참고
	•	템플릿 수정은 반드시 PR로 진행
	•	개발환경 문제가 생기면 Discord에서 공유 후 해결

끝.