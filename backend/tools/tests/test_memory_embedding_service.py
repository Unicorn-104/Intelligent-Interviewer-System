import importlib.util
import json
from pathlib import Path
import threading
import unittest
from urllib.error import HTTPError
from urllib.request import Request, urlopen

spec = importlib.util.spec_from_file_location('memory_embedding_service', Path(__file__).resolve().parents[1] / 'memory_embedding_service.py')
service = importlib.util.module_from_spec(spec)
spec.loader.exec_module(service)

class Vector:
    def tolist(self):
        return [0.1] * 512

class Model:
    def query_embed(self, texts):
        return [Vector() for _ in texts]
    passage_embed = query_embed

class EmbeddingContractTest(unittest.TestCase):
    def setUp(self):
        service.TOKEN = 'synthetic-embedding-token'
        service._model = Model()
        self.server = service.HTTPServer(('127.0.0.1', 0), service.Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.url = f'http://127.0.0.1:{self.server.server_port}/v1/embeddings'

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def request(self, authorization=None, **body):
        headers = {'Content-Type': 'application/json'}
        if authorization:
            headers['Authorization'] = authorization
        return urlopen(Request(self.url, json.dumps(body).encode(), headers), timeout=3)

    def test_token_required_and_bearer_returns_512_dimensions(self):
        with self.assertRaises(HTTPError) as error:
            self.request(input=['synthetic'])
        self.assertEqual(401, error.exception.code)
        with self.request('Bearer synthetic-embedding-token', input=['synthetic'], input_type='query') as response:
            self.assertEqual(512, len(json.load(response)['data'][0]['embedding']))

    def test_invalid_input_type_is_rejected(self):
        with self.assertRaises(HTTPError) as error:
            self.request('Bearer synthetic-embedding-token', input=['synthetic'], input_type='invalid')
        self.assertEqual(400, error.exception.code)

if __name__ == '__main__':
    unittest.main()
