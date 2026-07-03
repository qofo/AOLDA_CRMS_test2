# AOLDA_CRMS_test_fluentbit

Fluent Bit를 이용하여 시스템 메트릭(CPU, Memory, Disk, Network)을 수집하고, 정규화한 후 Gateway로 전송하는 예제 프로젝트입니다.

또한 실제 운영 환경에서 발생할 수 있는 다양한 상황을 가정하여 Buffer Test, Stress Test, Soak Test를 수행할 수 있는 테스트 스크립트를 제공합니다.

---

# 프로젝트 개요

본 프로젝트는 다음과 같은 흐름으로 동작합니다.

```
System Metrics
    │
    ▼
Fluent Bit Input Plugins
    │
    ▼
Record Modifier
    │
    ▼
Lua Normalizer
    │
    ▼
CRMS Schema
    │
    ▼
HTTP Gateway
```

수집되는 메트릭은 Fluent Bit의 Input Plugin을 통해 생성되며, Lua Filter에서 CRMS 표준 형식으로 변환된 후 HTTP Output Plugin을 통해 Gateway로 전송됩니다.

---

# 프로젝트 구성

```
.
├── buffer_test.sh              # 네트워크 장애(Buffer) 테스트
├── soak_test.sh                # 장시간(Soak) 테스트
├── stress_test.sh              # CPU/Memory Stress 테스트
│
├── fluent-bit.conf             # 기본 Fluent Bit 설정
├── fluent-bit-new.conf         # 운영 환경 예시 설정
├── fluent-bit.yaml             # Kubernetes 배포 예시
├── fluent-bit-new.yaml         # 개선된 Kubernetes 배포 예시
│
├── normalize.lua               # CRMS Schema 변환 Lua Filter
│
└── 기타 테스트 로그 및 결과 파일
```

---

# 주요 구성 요소

## fluent-bit.conf

기본적인 Fluent Bit 설정 파일입니다.

주요 기능

* CPU 메트릭 수집
* Memory 메트릭 수집
* Disk 메트릭 수집
* Network 메트릭 수집
* Record Modifier 적용
* Lua Filter 적용
* HTTP Output 전송

개발 및 기능 검증을 위한 기본 설정으로 사용할 수 있습니다.

---

## fluent-bit-new.conf

운영 환경을 고려한 예시 설정입니다.

기본 설정과 비교하여 다음 기능이 추가되었습니다.

* Filesystem Buffer 사용
* Flush 주기 조정
* Storage Path 지정
* Memory Backlog 제한

Gateway 장애 발생 시 메모리 사용량 증가를 줄이고 안정적인 데이터 전송을 지원합니다.

---

## normalize.lua

프로젝트의 핵심 구성 요소입니다.

Fluent Bit에서 수집한 메트릭을 CRMS Schema 형식으로 변환합니다.

주요 기능은 다음과 같습니다.

* 공통 Resource 정보 생성
* Metric Name 정규화
* Timestamp 생성
* CRMS Schema 구성
* 유효하지 않은 데이터 제거

값이 존재하지 않는 경우에는 레코드를 생성하지 않고 Drop하도록 구현되어 있습니다.

---

# 테스트 시나리오

## 1. Buffer Test

Gateway와의 통신이 불가능한 상황을 가정하여 Fluent Bit의 Buffer 동작을 검증합니다.

주요 검증 항목

* Retry 동작
* Buffer 적재
* Gateway 복구 이후 정상 전송 여부

---

## 2. Stress Test

CPU와 Memory에 높은 부하를 발생시켜 Fluent Bit의 안정성을 확인합니다.

주요 검증 항목

* 프로세스 생존 여부
* Memory 사용량 변화
* 로그 처리 지속 여부

---

## 3. Soak Test

장시간 Fluent Bit를 실행하여 안정성을 검증합니다.

주요 검증 항목

* Memory Leak 여부
* 장시간 동작 안정성
* 지속적인 로그 전송 여부

---

# 실행 환경

다음 환경을 기준으로 테스트되었습니다.

* Linux Ubuntu 24.04
* Fluent Bit
* Lua Filter
* stress-ng
* iptables

---

# 실행 방법

## Fluent Bit 실행

```
fluent-bit -c fluent-bit.conf
```

또는

```
fluent-bit -c fluent-bit-new.conf
```

---

## Stress Test 실행

```
./stress_test.sh
```

---

## Soak Test 실행

```
./soak_test.sh
```

---

## Buffer Test 실행

```
./buffer_test.sh
```

---

# 설정 항목

실행 환경에 따라 다음 항목을 수정해야 할 수 있습니다.

| 항목                | 설명                                 |
| ----------------- | ---------------------------------- |
| INSTANCE_ID       | 대상 VM 또는 서버 식별자                    |
| PROJECT_ID        | 프로젝트 식별자                           |
| Gateway Host      | HTTP Gateway 주소                    |
| Gateway Port      | HTTP Gateway 포트                    |
| Network Interface | 시스템 네트워크 인터페이스 이름(예: ens3, eth0 등) |

환경에 따라 Network Interface 이름이 다를 수 있으므로 설정 파일을 확인한 후 수정해야 합니다.

---

# 기대 결과

각 시스템 메트릭은 CRMS Schema 형식으로 변환되어 HTTP Gateway로 전송됩니다.

예시 구조는 다음과 같습니다.

```json
{
  "resource": {
    "...": "..."
  },
  "metric": {
    "...": "..."
  },
  "timestamp": "..."
}
```

---

# 제한 사항

* Linux 환경을 기준으로 작성되었습니다.
* `stress-ng`가 설치되어 있어야 Stress Test를 수행할 수 있습니다.
* Buffer Test는 `iptables` 사용 권한이 필요합니다.
* Gateway 주소 및 네트워크 인터페이스는 환경에 맞게 수정해야 합니다.

---

# 향후 개선 사항

* 환경 변수 기반 설정 지원
* Docker Compose 실행 환경 제공
* Kubernetes 배포 예제 보완
* 테스트 결과 자동 리포트 생성
* CI 기반 자동 검증 환경 구축
