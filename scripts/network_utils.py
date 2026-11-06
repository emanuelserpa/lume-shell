"""Shared network configuration helpers for standalone scripts."""
import socket


def prefer_ipv4_resolution():
    """Keep urllib/requests from waiting on unreachable advertised IPv6 routes."""
    original_getaddrinfo = socket.getaddrinfo

    def getaddrinfo_ipv4(host, port, family=0, type=0, proto=0, flags=0):
        return original_getaddrinfo(host, port, socket.AF_INET, type, proto, flags)

    socket.getaddrinfo = getaddrinfo_ipv4
