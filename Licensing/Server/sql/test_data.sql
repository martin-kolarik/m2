alter sequence hibernate_sequence increment by 100000
;
select hibernate_sequence.nextval from dual
;
alter sequence hibernate_sequence increment by 1
;
; Insert into TICKET_OPERATOR (OPERATOR_ID,ACTIVE,AUTHORIZATION_FAILURE_COUNT,AUTHORIZATION_TIMEOUT,CREATED,FIRST_NAME,LAST_NAME,NOTE,PASSWORD,TYPE,USER_NAME,VERSION,COMPANY) values (5,1,null,null,to_timestamp('30.06.08 13:28:00,000000000','DD.MM.RR HH24:MI:SS,FF'),'DPMUL','DPMUL Uživatel','DPMUL Uživatel','erLrzfaXXR/TngQbR0YloA==','USER','dpmul_user',0,1)
;
