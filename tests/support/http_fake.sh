read -r -d '' HTTP_FAKE_PY <<'PY' || true
import io, json, urllib.error, urllib.request

ASC = "https://api.appstoreconnect.apple.com"
requests, unknown = [], []


class Response:
    def __init__(self, body):
        self.body = body

    def read(self):
        return self.body

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


def install(route):
    def urlopen(request, timeout=None):
        if isinstance(request, str):
            method, url, data = "GET", request, None
        else:
            method, url, data = request.get_method(), request.full_url, request.data
        short = url[len(ASC):] if url.startswith(ASC) else url
        try:
            body = json.loads(data) if data else None
        except ValueError:
            body = data
        requests.append((method, short, body))
        result = route(method, short, body)
        if result is None:
            unknown.append(f"{method} {short}")
            raise urllib.error.URLError(f"知らない URL: {method} {short}")
        if isinstance(result, tuple):
            raise urllib.error.HTTPError(url, result[0], "error", {}, io.BytesIO(result[1].encode()))
        return Response(result if isinstance(result, bytes) else json.dumps(result).encode())

    urllib.request.urlopen = urlopen


def report_unknown():
    for line in unknown:
        print(f"UNKNOWN {line}")
PY
export HTTP_FAKE_PY

asc_keys() {
    openssl ecparam -name prime256v1 -genkey -noout -out "$work/asc-key.pem" 2>/dev/null
    export ASC_ISSUER_ID=issuer ASC_KEY_ID=key ASC_KEY_PATH="$work/asc-key.pem"
}
