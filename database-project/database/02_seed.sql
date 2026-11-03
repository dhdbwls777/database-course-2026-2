-- BalanceBook 02 기준 데이터(Seed) 입력
-- 실행 위치: balancebook 데이터베이스, 01_schema.sql 실행 후
-- 시작 상태: acct 테이블 10개 모두 0행
-- 완료 상태: Chapter 07 완료 기준 2번의 행 수
--   companies 2 / users 2 / company_users 3 / accounts 6 / partners 1
--   fiscal_periods 2 / journal_entries 4 / journal_lines 10 / evidences 1 / entry_change_logs 4
-- 근거: Chapter 05 답안 16번 시나리오(가나카페 사건 1~4, 전표가 없는 다라학원)
-- 전체 입력을 하나의 트랜잭션으로 실행합니다.

SELECT current_database();
SELECT current_user;

BEGIN;

DO $$
BEGIN
    IF current_database() <> 'balancebook' THEN
        RAISE EXCEPTION
            '입력 중단: 현재 데이터베이스는 %입니다. balancebook에 연결하세요.',
            current_database();
    END IF;

    IF to_regclass('acct.journal_lines') IS NULL THEN
        RAISE EXCEPTION
            '입력 중단: acct 테이블이 없습니다. 01_schema.sql을 먼저 실행하세요.';
    END IF;
END
$$;

-- 사업자 2곳: 다라학원은 가입만 하고 아직 전표가 없다.
INSERT INTO acct.companies (company_id, name, business_no)
VALUES
    (1, '가나카페', '111-11-11111'),
    (2, '다라학원', '222-22-22222');

-- 사용자 2명: 김가나는 가나카페 대표, 이세무는 두 사업자를 맡은 세무대리인
INSERT INTO acct.users (user_id, email, name)
VALUES
    (1, 'gana@example.com', '김가나'),
    (2, 'semu@example.com', '이세무');

-- 사용자-사업자 연결 3건: 이세무 한 명이 두 사업자를 맡고, 가나카페에는 사용자가 두 명이다.
INSERT INTO acct.company_users (company_user_id, company_id, user_id, role)
VALUES
    (1, 1, 1, '대표'),
    (2, 1, 2, '검토자'),
    (3, 2, 2, '검토자');

-- 표준 계정과목 6개: 유동자산 아래에 보통예금, 부가세대급금, 원재료가 있다.
INSERT INTO acct.accounts (account_id, parent_account_id, code, name, account_type)
VALUES
    (1, NULL, '100', '유동자산', '자산'),
    (2, 1, '103', '보통예금', '자산'),
    (3, 1, '135', '부가세대급금', '자산'),
    (4, 1, '153', '원재료', '자산'),
    (5, NULL, '251', '외상매입금', '부채'),
    (6, NULL, '819', '임차료', '비용');

-- 거래처 1곳: 가나카페가 등록한 가나로스터리
INSERT INTO acct.partners (partner_id, company_id, name, business_no)
VALUES
    (1, 1, '가나로스터리', '333-33-33333');

-- 마감 기간 2개: 가나카페 10월은 이세무가 마감했고, 11월은 열려 있다.
-- 10월 전표 4장은 마감된 달의 전표이므로, 고칠 일이 생기면 11월에 역분개 전표로 정정한다.
INSERT INTO acct.fiscal_periods (period_id, company_id, year_month, is_closed, closed_by)
VALUES
    (1, 1, '2026-10', true, 2),
    (2, 1, '2026-11', false, NULL);

-- 전표 4장: 가나카페 사건 1~4, 작성자는 김가나
INSERT INTO acct.journal_entries (entry_id, company_id, created_by, reversal_of_entry_id, entry_date, description)
VALUES
    (1, 1, 1, NULL, '2026-10-02', '원두 외상 매입'),
    (2, 1, 1, NULL, '2026-10-09', '원두 외상 매입'),
    (3, 1, 1, NULL, '2026-10-20', '외상매입금 지급'),
    (4, 1, 1, NULL, '2026-10-25', '10월 임차료 지급');

-- 분개 10줄: 거래처는 외상매입금 줄에만 기록한다.
INSERT INTO acct.journal_lines (line_id, entry_id, account_id, partner_id, debit_amount, credit_amount)
VALUES
    -- 사건 1: 원재료 300,000 + 부가세대급금 30,000 / 외상매입금 330,000
    (1, 1, 4, NULL, 300000, 0),
    (2, 1, 3, NULL, 30000, 0),
    (3, 1, 5, 1, 0, 330000),
    -- 사건 2: 사건 1과 같은 거래를 한 번 더
    (4, 2, 4, NULL, 300000, 0),
    (5, 2, 3, NULL, 30000, 0),
    (6, 2, 5, 1, 0, 330000),
    -- 사건 3: 외상매입금 330,000 / 보통예금 330,000
    (7, 3, 5, 1, 330000, 0),
    (8, 3, 2, NULL, 0, 330000),
    -- 사건 4: 임차료 1,000,000 / 보통예금 1,000,000
    (9, 4, 6, NULL, 1000000, 0),
    (10, 4, 2, NULL, 0, 1000000);

-- 증빙 1건: 사건 1의 세금계산서
INSERT INTO acct.evidences (evidence_id, entry_id, evidence_type, issue_date, amount)
VALUES
    (1, 1, '세금계산서', '2026-10-02', 330000);

-- 변경 기록 4건: 전표마다 생성 기록 하나
INSERT INTO acct.entry_change_logs (log_id, entry_id, user_id, action, changed_at)
VALUES
    (1, 1, 1, '생성', '2026-10-02 10:00:00+09'),
    (2, 2, 1, '생성', '2026-10-09 10:00:00+09'),
    (3, 3, 1, '생성', '2026-10-20 10:00:00+09'),
    (4, 4, 1, '생성', '2026-10-25 10:00:00+09');

-- 번호를 직접 넣었으므로, 다음에 자동으로 붙을 번호를 그 다음 번호부터 시작하게 한다.
ALTER TABLE acct.companies ALTER COLUMN company_id RESTART WITH 3;
ALTER TABLE acct.users ALTER COLUMN user_id RESTART WITH 3;
ALTER TABLE acct.company_users ALTER COLUMN company_user_id RESTART WITH 4;
ALTER TABLE acct.accounts ALTER COLUMN account_id RESTART WITH 7;
ALTER TABLE acct.partners ALTER COLUMN partner_id RESTART WITH 2;
ALTER TABLE acct.fiscal_periods ALTER COLUMN period_id RESTART WITH 3;
ALTER TABLE acct.journal_entries ALTER COLUMN entry_id RESTART WITH 5;
ALTER TABLE acct.journal_lines ALTER COLUMN line_id RESTART WITH 11;
ALTER TABLE acct.evidences ALTER COLUMN evidence_id RESTART WITH 2;
ALTER TABLE acct.entry_change_logs ALTER COLUMN log_id RESTART WITH 5;

COMMIT;

-- 확인: 테이블별 실제 행 수와 기대 행 수
SELECT 'companies' AS table_name, COUNT(*) AS row_count, 2 AS expected FROM acct.companies
UNION ALL
SELECT 'users', COUNT(*), 2 FROM acct.users
UNION ALL
SELECT 'company_users', COUNT(*), 3 FROM acct.company_users
UNION ALL
SELECT 'accounts', COUNT(*), 6 FROM acct.accounts
UNION ALL
SELECT 'partners', COUNT(*), 1 FROM acct.partners
UNION ALL
SELECT 'fiscal_periods', COUNT(*), 2 FROM acct.fiscal_periods
UNION ALL
SELECT 'journal_entries', COUNT(*), 4 FROM acct.journal_entries
UNION ALL
SELECT 'journal_lines', COUNT(*), 10 FROM acct.journal_lines
UNION ALL
SELECT 'evidences', COUNT(*), 1 FROM acct.evidences
UNION ALL
SELECT 'entry_change_logs', COUNT(*), 4 FROM acct.entry_change_logs;
