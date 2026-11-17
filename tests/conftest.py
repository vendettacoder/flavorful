"""All backend tests use local doubles, never network services or .env values."""

import socket

import dotenv
import pytest
import requests


@pytest.fixture(autouse=True)
def no_external_services(monkeypatch):
    def blocked(*args, **kwargs):
        raise AssertionError("Test attempted an external network operation")

    monkeypatch.setattr(dotenv, "load_dotenv", lambda *args, **kwargs: False)
    monkeypatch.setattr(socket, "getaddrinfo", blocked)
    monkeypatch.setattr(socket.socket, "connect", blocked)
    monkeypatch.setattr(socket.socket, "connect_ex", blocked)
    monkeypatch.setattr(socket.socket, "sendto", blocked)
    monkeypatch.setattr(requests, "post", blocked)
