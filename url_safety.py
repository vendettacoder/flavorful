"""SSRF protection + URL validation for user-supplied recipe links.

The backend fetches arbitrary user URLs with Playwright, so we must ensure those
URLs only point at the public internet — never internal/loopback/link-local/cloud
metadata addresses. Pure stdlib (socket + ipaddress); no extra dependencies.
"""

import ipaddress
import socket
from urllib.parse import urlparse

from fastapi import HTTPException

_MAX_URL_LEN = 2048
_ALLOWED_SCHEMES = {"http", "https"}

# Generic message — never reveal *why* a URL was rejected (no SSRF probing oracle).
_REJECT = HTTPException(status_code=400, detail="That link can't be opened.")


def _ip_is_blocked(ip_str: str) -> bool:
    try:
        ip = ipaddress.ip_address(ip_str)
    except ValueError:
        return True  # unparseable → block to be safe
    return (
        ip.is_private
        or ip.is_loopback
        or ip.is_link_local  # includes 169.254.169.254 cloud metadata
        or ip.is_reserved
        or ip.is_multicast
        or ip.is_unspecified
    )


def is_blocked_host(host: str) -> bool:
    """True if host is, or resolves to, a non-public IP. Blocks on any failure.

    Used both for the input URL and for every Playwright request (so redirects
    and sub-resources to internal hosts are caught too).
    """
    if not host:
        return True
    # Literal IP?
    try:
        ipaddress.ip_address(host)
        return _ip_is_blocked(host)
    except ValueError:
        pass
    # Resolve DNS; block if resolution fails or ANY address is internal.
    try:
        infos = socket.getaddrinfo(host, None)
    except socket.gaierror:
        return True
    return any(_ip_is_blocked(info[4][0]) for info in infos)


def validate_public_url(url: str) -> str:
    """Validate that `url` is a fetchable public http(s) address.

    Raises HTTPException(400) with a generic message on any problem.
    """
    if not url or len(url) > _MAX_URL_LEN:
        raise _REJECT
    parsed = urlparse(url)
    if parsed.scheme not in _ALLOWED_SCHEMES:
        raise _REJECT
    host = parsed.hostname
    if not host or is_blocked_host(host):
        raise _REJECT
    return url
