Bugzilla::Dashboard
====================

버그질라 대시보드는 다음의 기능을 제공하는 것을 목표로 합니다.

- 최근 변경 이력의 제공 ( bug 286 )
- 최근 변경 첨부파일 이력의 제공 ( bug 287 )
- 나에게 할당된 버그 이력의 제공 ( bug 288 )
- 탐색창 추가 ( bug 289 )
- 빠른 이슈 생성 창 추가 ( bug 290 )
- 각 사용자별의 사용 통계표 제공 ( bug 291 )
- IRC Notification ( bug 292 )


환경 변수
----------

다음 세 개의 환경 변수를 사용합니다.

- `BUGZILLA_DASHBOARD_USER`: 버그질라 로그인 아이디
- `BUGZILLA_DASHBOARD_PASSOWRD`: 버그질라 로그인 비밀번호
- `BUGZILLA_DASHBOARD_URI`: 버그질라 JSON-RPC 주소


실행
-----

    $ PERL5LIB=lib morbo bugzilla-dashboard-web.pl


테스트
-------

    $ prove -l
