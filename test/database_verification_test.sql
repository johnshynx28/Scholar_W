-- Run against an isolated PostgreSQL test database AFTER bootstrap, base schema,
-- and verification migration. Never run these fixture accounts in production.
\set ON_ERROR_STOP on
begin;
create function public.test_assert(v boolean, label text) returns void language plpgsql as $$
begin if not coalesce(v,false) then raise exception 'ASSERTION FAILED: %',label; end if;
raise notice 'PASS: %', label; end $$;
create function public.test_denied(statement text, label text) returns void language plpgsql as $$
begin
  begin execute statement;
  exception when others then raise notice 'PASS: % (%)',label,sqlerrm; return;
  end;
  raise exception 'ASSERTION FAILED: unauthorized operation succeeded: %', label;
end $$;
grant execute on function public.test_assert(boolean,text),public.test_denied(text,text) to authenticated,anon;

insert into public.profiles(id,full_name,email,role,is_active) values
 ('admin-test','Administrator','admin@test.edu','admin',true);

set local role authenticated;
set local request.jwt.claims = '{"sub":"student-test","email":"student@test.edu","role":"authenticated"}';
insert into public.profiles(id,full_name,email,role,declared_scholar,scholarship_name,is_active)
 values('student-test','Test Scholar','student@test.edu','scholar',true,'School Merit Award',false);
select public.test_assert((select verification_status='pending' and not is_active from public.profiles where id='student-test'), 'registration starts pending and inactive');
select public.test_assert((select count(*)=1 from public.profiles),'student cannot list other profiles');
select public.test_denied($q$update public.profiles set verification_status='approved',is_active=true where id='student-test'$q$, 'student cannot self-approve');
select public.test_denied($q$update public.profiles set role='admin' where id='student-test'$q$, 'student cannot become admin');
select public.test_denied($q$update public.profiles set balance=99999 where id='student-test'$q$, 'student cannot edit balance');
select public.test_denied($q$select public.issue_verified_payout('Forged batch',array['student-test'])$q$, 'student cannot issue a payout');
select public.test_denied($q$select public.review_registration('student-test','pending','approved','',true)$q$, 'student cannot invoke admin review');
select public.test_denied($q$select public.claim_allowance('fake','student-test')$q$, 'pending scholar cannot redeem');
select public.test_denied($q$insert into public.profiles(id,full_name,email,role,is_active) values('forged-admin','Fake','student@test.edu','admin',true)$q$, 'registration cannot forge admin role');

set local request.jwt.claims = '{"sub":"admin-test","email":"admin@test.edu","role":"authenticated"}';
select public.test_denied($q$select public.review_registration('student-test','pending','approved','',false)$q$, 'approval requires roster attestation');
select public.review_registration('student-test','pending','under_review','Checking school roster',false);
select public.test_denied($q$select public.review_registration('student-test','pending','rejected','Wrong stale form',false)$q$, 'stale review is rejected');
select public.test_denied($q$select public.review_registration('student-test','under_review','needs_info','',false)$q$, 'request information requires notes');
select public.review_registration('student-test','under_review','needs_info','Please provide the award reference',false);

set local request.jwt.claims = '{"sub":"student-test","email":"student@test.edu","role":"authenticated"}';
select public.resubmit_registration(true,'School Merit Award','AWARD-2026-123');
select public.test_assert((select verification_status='pending' and scholarship_reference='AWARD-2026-123' from public.profiles where id='student-test'), 'same registration resubmits requested information');
select public.test_denied($q$select public.resubmit_registration(true,'Changed again','')$q$, 'cannot resubmit unless information requested');

set local request.jwt.claims = '{"sub":"admin-test","email":"admin@test.edu","role":"authenticated"}';
select public.review_registration('student-test','pending','approved','Matched official roster',true);
select public.test_assert((select verification_status='approved' and is_active from public.profiles where id='student-test'),'verified approval enables payout access');
select public.test_assert((select count(*)=4 from public.registration_reviews where scholar_id='student-test'),'review and resubmission history recorded');
select public.test_denied($q$select public.review_registration('student-test','approved','rejected','Changed mind',false)$q$, 'final review cannot be overwritten');
select public.test_denied($q$select public.issue_verified_payout('Invalid batch',array['student-test','missing-user'])$q$,'invalid recipient aborts whole payout');
select public.test_assert((select count(*)=0 from public.disbursements),'failed batch leaves no partial records');
select public.issue_verified_payout('October Allowance',array['student-test','student-test']);
select public.test_assert((select count(*)=1 from public.allowance_claims),'duplicate recipient IDs yield one QR only');
select public.test_assert((select amount=5000 and length(token)=32 from public.allowance_claims),'server fixed amount and manual-entry token');
select token as issued_token from public.allowance_claims where scholar_id='student-test' \gset
select public.set_verified_scholar_active('student-test',false);

set local request.jwt.claims = '{"sub":"student-test","email":"student@test.edu","role":"authenticated"}';
select public.test_denied(format('select public.claim_allowance(%L,%L)', :'issued_token','student-test'),'suspended verified scholar cannot redeem');
set local request.jwt.claims = '{"sub":"admin-test","email":"admin@test.edu","role":"authenticated"}';
select public.set_verified_scholar_active('student-test',true);

set local request.jwt.claims = '{"sub":"other-test","email":"other@test.edu","role":"authenticated"}';
insert into public.profiles(id,full_name,email,role,declared_scholar,scholarship_name,is_active)
 values('other-test','Other Scholar','other@test.edu','scholar',true,'Other Award',false);
select public.test_assert((select count(*)=0 from public.allowance_claims),'other account cannot read payout QR tokens');
select public.test_denied(format('select public.claim_allowance(%L,%L)', :'issued_token','student-test'),'caller cannot impersonate another scholar');
set local request.jwt.claims = '{"sub":"admin-test","email":"admin@test.edu","role":"authenticated"}';
select public.review_registration('other-test','pending','approved','Verified',true);
set local request.jwt.claims = '{"sub":"other-test","email":"other@test.edu","role":"authenticated"}';
select public.test_denied(format('select public.claim_allowance(%L,%L)', :'issued_token','other-test'),'verified wrong recipient still cannot redeem');

set local request.jwt.claims = '{"sub":"student-test","email":"student@test.edu","role":"authenticated"}';
select public.claim_allowance(:'issued_token','student-test');
select public.test_assert((select balance=5000 from public.profiles where id='student-test'),'successful receipt credits balance');
select public.test_denied(format('select public.claim_allowance(%L,%L)', :'issued_token','student-test'),'same QR cannot be redeemed twice');
select public.test_assert((select count(*)=1 from public.transactions),'receipt writes one transaction only');
select public.test_assert((select count(*)=1 from public.disbursements where status='completed'),'payout event completes after receipt');
with attempted as (update public.allowance_claims set status='received' returning id)
select public.test_assert((select count(*)=0 from attempted),'client cannot directly change claim state');

set local request.jwt.claims = '{"sub":"non-scholar-test","email":"non@test.edu","role":"authenticated"}';
insert into public.profiles(id,full_name,email,declared_scholar,is_active)
 values('non-scholar-test','Not Scholar','non@test.edu',false,false);
set local request.jwt.claims = '{"sub":"admin-test","email":"admin@test.edu","role":"authenticated"}';
select public.test_denied($q$select public.review_registration('non-scholar-test','pending','approved','',true)$q$, 'non-scholar declaration cannot be approved');
select public.review_registration('non-scholar-test','pending','rejected','Not on official scholarship roster',false);
select public.test_denied($q$select public.issue_verified_payout('Rejected payout',array['non-scholar-test'])$q$, 'rejected registration excluded from payout');

-- Cash Out (mockup) + admin delete
set local request.jwt.claims = '{"sub":"student-test","email":"student@test.edu","role":"authenticated"}';
select public.link_account('gcash','','Test Scholar','0917 123 4567');
select id as acc_id from public.linked_accounts where scholar_id='student-test' \gset
select public.test_denied($q$select public.link_account('gcash','','Test Scholar','12345')$q$,'invalid mobile number is rejected');
select public.test_denied(format('select public.request_withdrawal(%s,50)', :'acc_id'),'cash-out below PHP 100 is rejected');
select public.test_denied(format('select public.request_withdrawal(%s,100.555)', :'acc_id'),'cash-out with 3 decimals is rejected');
select public.test_denied(format('select public.request_withdrawal(%s,999999)', :'acc_id'),'cash-out above balance is rejected');
select public.request_withdrawal(:'acc_id', 1000.50);
select public.test_assert((select balance=3999.50 from public.profiles where id='student-test'),'cash-out deducts the balance');
select public.test_assert((select count(*)=1 from public.withdrawals where reference like 'SIM-%' and status='completed'),'cash-out recorded with simulated reference');
select public.test_assert((select count(*)=1 from public.transactions where type='debit' and amount=-1000.50),'cash-out writes a debit transaction');
set local request.jwt.claims = '{"sub":"other-test","email":"other@test.edu","role":"authenticated"}';
select public.test_denied(format('select public.request_withdrawal(%s,100)', :'acc_id'),'cannot cash out to another scholar''s account');
set local request.jwt.claims = '{"sub":"admin-test","email":"admin@test.edu","role":"authenticated"}';
select public.test_denied($q$select public.admin_delete_scholar('student-test')$q$,'cannot delete a scholar who still has a balance');
select public.test_denied($q$select public.admin_delete_scholar('admin-test')$q$,'cannot delete an admin');
set local request.jwt.claims = '{"sub":"student-test","email":"student@test.edu","role":"authenticated"}';
select public.request_withdrawal(:'acc_id', 3999.50);
set local request.jwt.claims = '{"sub":"admin-test","email":"admin@test.edu","role":"authenticated"}';
select public.admin_delete_scholar('student-test');
select public.test_assert((select count(*)=0 from public.profiles where id='student-test'),'admin deletes a scholar with linked accounts and cash-outs');
select public.test_assert((select public.admin_delete_inactive_scholars()=1),'sweep deletes rejected zero-balance accounts only');

set local request.jwt.claims = '{}';
set local role anon;
select public.test_assert((select count(*)=0 from public.profiles),'request without a valid token sees no profiles');
select public.test_assert((select count(*)=0 from public.allowance_claims),'request without a valid token sees no payout QR tokens');
select public.test_denied(format('select public.claim_allowance(%L,%L)', :'issued_token','student-test'),'request without a valid token cannot invoke payout RPC');
reset role;
rollback;
