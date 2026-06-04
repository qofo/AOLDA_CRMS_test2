-- TODO 현재는 단일 함수에서 조건문으로 메트릭별로 처리하고 있지만, yaml에서 메트릭을 구분하고 각각 다른 함수를 호출는 방식으로 리팩토링해야 합니다.

-- Fluent Bit가 수집한 텔레메트리 원시 레코드를 CRMS 스키마 규격으로 재구성합니다.
function format_to_crms_schema(tag, timestamp, record)
    local new_record = {}
    
    -- 1. 인프라 자원 구성 요소 생성
    -- 수집 데이터의 출처를 식별하기 위해 환경 메타데이터(인스턴스 및 프로젝트)를 매핑합니다.
    new_record["resource"] = {
        ["type"] = "instance",
        ["id"] = record["resource_id"] or "unknown_instance",
        ["project_id"] = record["project_id"] or "unknown_project"
    }

    -- 2. Metric Specifications Initialization
    -- 기본값 설정
    local metric_name = tag
    local metric_type = "gauge"
    local metric_unit = "unknown"
    local value = 0.0

    -- 3. 수집 태그 기반 라우팅 및 원시 메트릭 정규화
    -- 입력 플러그인의 고유 태그를 식별하여 내부 필드 값들을 표준 포맷으로 변환합니다.
    if tag == "guest.cpu" then
        -- CPU 사용률 파싱
        metric_name = "guest.cpu.util"
        metric_unit = "percent"
        value = record["cpu_p"] or 0.0
        
    elseif tag == "guest.memory" then
        -- 메모리 사용률 퍼센트 계산 및 파싱
        metric_name = "guest.memory.used_percent"
        metric_unit = "percent"
        -- value = record["Mem.used_p"] or 0.0
        local mem_total = record["Mem.total"] or 1
        local mem_used = record["Mem.used"] or 0
        value = (mem_used / mem_total) * 100
        
    elseif tag == "guest.net" then
        -- 네트워크 트래픽 파싱 (인터페이스 수신 바이트)
        -- 시간이 지남에 따라 누적되는 수신 바이트(rx.bytes) 총량을 추적하도록 누적 카운터 유형으로 설정합니다.
        metric_name = "guest.net.in.bytes"
        metric_type = "cumulative"
        metric_unit = "bytes"
        value = record["rx.bytes"] or 0.0
        
    elseif tag == "guest.disk" then
        -- 스토리지 서브시스템 I/O 파싱 (디스크 읽기 바이트)
        -- 디스크에서 읽어온 누적 바이트 크기를 추적하기 위해 누적 카운터 유형으로 설정합니다.
        metric_name = "guest.disk.read.bytes"
        metric_type = "cumulative"
        metric_unit = "bytes"
        value = record["read_size"] or 0.0
    end

    -- 표준화된 메트릭 정의 블록 구성
    new_record["metric"] = {
        ["name"] = metric_name,
        ["type"] = metric_type,
        ["unit"] = metric_unit
    }

    -- 4. Timestamp Serialization
	-- Fluent Bit의 Lua 필터는 타임스탬프를 2가지 형태로 넘겨줄 수 있습니다. 
	-- 1) Number 형태: Unix Epoch Time (초 단위) 
	-- 2) Table 형태: 고해상도 타이머인 경우 {sec = 초, nsec = 나노초} 형태의 테이블 
	-- 여기서는 Table 형태일 경우 초 단위만 추출하여 규격을 통일합니다.
    local ts = timestamp
    if type(timestamp) == "table" then
        ts = timestamp["sec"]
    end

    -- 정제된 타임스탬프와 최종 연산된 메트릭 값을 측정 데이터 블록으로 결합합니다.
    new_record["measure"] = {
        ["timestamp"] = ts,
        ["value"] = value
    }

    -- 5. 파이프라인 핸드셰이크 리턴 
    -- 상태 코드 '1'은 Fluent Bit 엔진에게 기존 원시 레코드를 삭제하고 새로 가공된 구조체('new_record')로 대체하라는 신호를 전달합니다.
    -- -1: 현재 레코드를 Drop함 
    -- 0: 변경 사항 없음 (원래 레코드 유지) 
    -- 1: 레코드가 수정되었음 (변경된 레코드로 덮어씀) 
    -- 2: 레코드와 타임스탬프가 모두 수정되었음
    return 1, timestamp, new_record
end