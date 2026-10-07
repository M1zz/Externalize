// 예전 주소(?lang=en)로 들어온 사람을 그 언어의 페이지로 보낸다.
// 언어마다 정적 페이지가 따로 있다: 한국어는 루트(·/ko/), 영어는 /en/.
(function () {
  var l = new URLSearchParams(location.search).get("lang");
  if (l && l.toLowerCase().indexOf("en") === 0) {
    var page = location.pathname.split("/").pop() || "";
    location.replace("en/" + page + location.hash);
  }
})();
