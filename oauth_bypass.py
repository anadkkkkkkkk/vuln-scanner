#!/usr/bin/env python3
# oauth_bypass.py - اختبار OAuth (تجريبي)
import requests

class MetaOAuthTester:
    def __init__(self, target_app="facebook", access_token="mock"):
        self.target = target_app
        self.token = access_token
        self.session = requests.Session()
    def test_oauth_redirect_uri(self):
        payloads = ["https://evil.com/oauth_callback", "//evil.com/callback"]
        for payload in payloads:
            url = f"https://www.facebook.com/v19.0/dialog/oauth?client_id=123&redirect_uri={payload}&scope=email"
            r = self.session.get(url, allow_redirects=False)
            print(f"[*] Testing {payload} -> HTTP {r.status_code}")
    def test_graphql_injection(self):
        queries = ["{__schema{types{name}}}", "{user(id:\"1\"){id,email}}"]
        for q in queries:
            print(f"[*] GQL query: {q[:30]}... (mock)")

if __name__ == "__main__":
    tester = MetaOAuthTester()
    tester.test_oauth_redirect_uri()
    tester.test_graphql_injection()
