"""Currency formatting for UZS soʻm.

Usage: {% load uzs %}  ->  {{ invoice.amount|uzs }}  ->  "200 ming soʻm"

Round thousands/millions render the local "ming"/"million" words; other
amounts fall back to comma-grouped digits (e.g. "200,500 soʻm").
"""
from decimal import Decimal, InvalidOperation

from django import template

from ..payments import format_uzs_number

register = template.Library()


@register.filter
def uzs(value, suffix="soʻm"):
    """Format a number as UZS soʻm (e.g. "200 ming soʻm", "200,500 soʻm")."""
    if value is None or value == "":
        return "—"
    try:
        Decimal(value)
    except (InvalidOperation, TypeError, ValueError):
        return value
    return f"{format_uzs_number(value)} {suffix}".strip()


@register.filter
def uzs_plain(value):
    """UZS amount without the currency suffix (for tables)."""
    return uzs(value, suffix="")
