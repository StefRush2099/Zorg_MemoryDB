#!/usr/bin/env python3
"""Shared rich-text email helpers for Zorg Gmail sends.

Default policy: outbound email should be multipart/alternative with a
plain-text fallback and a text/html part for professional rendering.
"""
from __future__ import annotations

import html
import re
from email.message import EmailMessage

from email_signature import append_html, append_plain


def plain_to_html(body: str) -> str:
    """Convert tasteful plain text into simple professional HTML."""
    text = (body or "").strip()
    if not text:
        return append_html("")
    # If the caller already supplied HTML, only ensure signature is present.
    if re.search(r"<\s*(p|div|br|ul|ol|li|strong|html|body|h[1-6])\b", text, re.I):
        return append_html(text)

    blocks = re.split(r"\n\s*\n", text)
    html_blocks: list[str] = []
    list_items: list[str] = []

    def flush_list():
        nonlocal list_items
        if list_items:
            html_blocks.append("<ul>" + "".join(f"<li>{item}</li>" for item in list_items) + "</ul>")
            list_items = []

    for block in blocks:
        lines = [ln.rstrip() for ln in block.splitlines() if ln.strip()]
        if not lines:
            continue
        if all(re.match(r"^[-*•]\s+", ln) for ln in lines):
            for ln in lines:
                list_items.append(html.escape(re.sub(r"^[-*•]\s+", "", ln)).replace("\n", "<br>"))
            continue
        flush_list()
        safe = "<br>".join(html.escape(ln) for ln in lines)
        html_blocks.append(f"<p>{safe}</p>")
    flush_list()
    return append_html("\n".join(html_blocks))


def set_rich_text_content(msg: EmailMessage, body_text: str, body_html: str | None = None) -> None:
    """Attach plain + HTML alternatives to an EmailMessage.

    Use this instead of msg.set_content(...) for outbound email.
    """
    plain = append_plain(body_text or "")
    html_body = append_html(body_html) if body_html else plain_to_html(plain)
    msg.set_content(plain)
    msg.add_alternative(html_body, subtype="html")
