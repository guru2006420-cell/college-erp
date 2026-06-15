"""
Send tuition payment reminders for unpaid invoices.

Usage:
    python manage.py send_payment_reminders
    python manage.py send_payment_reminders --due-soon-days 3 --overdue-every 3
    python manage.py send_payment_reminders --dry-run

Intended to be run daily on a cron. For each open (due/partial) invoice it
sends an in-app notification + email (+ Eskiz SMS when configured) when:
  - the due date is within --due-soon-days days (default 3), or
  - the invoice is overdue and the last reminder was sent at least
    --overdue-every days ago (default 3).

send_invoice_reminder() itself deduplicates to one reminder per invoice
per day, so re-running the command is always safe.
"""

from datetime import timedelta

from django.core.management.base import BaseCommand
from django.utils import timezone

from main_app.models import Invoice
from main_app.payments import send_invoice_reminder


class Command(BaseCommand):
    help = "Send in-app/email/SMS reminders for due and overdue tuition invoices."

    def add_arguments(self, parser):
        parser.add_argument(
            "--due-soon-days",
            type=int,
            default=3,
            help="Remind when the due date is within this many days (default: 3).",
        )
        parser.add_argument(
            "--overdue-every",
            type=int,
            default=3,
            help="While overdue, remind again every N days (default: 3).",
        )
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="List the invoices that would be reminded without sending anything.",
        )

    def handle(self, *args, **opts):
        today = timezone.localdate()
        soon = today + timedelta(days=opts["due_soon_days"])
        repeat_cutoff = today - timedelta(days=opts["overdue_every"])

        open_invoices = Invoice.objects.filter(
            status__in=[Invoice.STATUS_DUE, Invoice.STATUS_PARTIAL]
        ).select_related("student__admin", "group")

        candidates = []
        for invoice in open_invoices:
            if invoice.due_date <= today:  # overdue (or due today)
                if invoice.last_reminded_on is None or invoice.last_reminded_on <= repeat_cutoff:
                    candidates.append(invoice)
            elif invoice.due_date <= soon:  # approaching due date
                if invoice.last_reminded_on is None or invoice.last_reminded_on < today:
                    candidates.append(invoice)

        if opts["dry_run"]:
            for invoice in candidates:
                self.stdout.write(
                    f"WOULD REMIND: {invoice.student} · {invoice.period_label} · "
                    f"balance {invoice.balance} · due {invoice.due_date}"
                )
            self.stdout.write(
                self.style.SUCCESS(f"{len(candidates)} reminder(s) pending (dry run).")
            )
            return

        sent = sum(1 for invoice in candidates if send_invoice_reminder(invoice))
        self.stdout.write(self.style.SUCCESS(f"Sent {sent} payment reminder(s)."))
