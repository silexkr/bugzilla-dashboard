bugzilla-dashboard
==================

Bugzilla 의 DashBoard 구현

Bugzilla 에 다음의 기능을 제공하는 DashBoard 구현을 목표로
다음의 이슈들을 생성하였습니다.

- 최근 변경 이력의 제공 ( bug 286 )
- 최근 변경 첨부파일 이력의 제공 ( bug 287 )
- 나에게 할당된 버그 이력의 제공 ( bug 288 )
- 탐색창 추가 ( bug 289 )
- 빠른 이슈 생성 창 추가 ( bug 290 )
- 각 사용자별의 사용 통계표 제공 ( bug 291 )
- IRC Notification (optional) ( bug 292 )

### RUN ###

    $ cd web/
    $ plackup bz.pl # HTTP::Server::PSGI: Accepting connections at http://0:5000/

### TEST ###

3개의 `env` 가 필요합니다.

- `BZ_DASHBOARD_USERNAME` - **required**
- `BZ_DASHBOARD_PASSOWRD` - **required**
- `BZ_DASHBOARD_URI` - optional. 'http://bugs.silex.kr/jsonrpc.cgi' as default

        $ export BZ_DASHBOARD_USERNAME="your@email.com"
        $ export BZ_DASHBOARD_PASSWORD="s3cr3t passw0rd"
        $ export BZ_DASHBOARD_URI="http://bugs.silex.kr/jsonrpc.cgi"
        $ prove -l
