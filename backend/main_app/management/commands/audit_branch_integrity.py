"""Audit (and optionally fix) branch-first data integrity.

Read-only by default — prints a report of records that need attention. With
``--fix`` it will safely fill *unambiguous* null branches:

    python manage.py audit_branch_integrity          # report only
    python manage.py audit_branch_integrity --fix     # backfill + report

The fixer only acts when there is exactly one obvious branch:
  * Student.branch  ← the branch of the student's active enrollment groups,
                      but only when all such groups share one branch.
  * Staff.branch    ← the branch of the groups they teach, but only when all
                      taught groups share one branch.
Ambiguous cases (groups across multiple branches) are reported, never guessed.
"""

from django.core.management.base import BaseCommand
from django.db.models import Count

from main_app.models import Enrollment, Group, Staff, Student


class Command(BaseCommand):
    help = "Report (and optionally --fix) branch-first data integrity issues."

    def add_arguments(self, parser):
        parser.add_argument(
            "--fix",
            action="store_true",
            help="Backfill unambiguous null branches. Ambiguous cases are only reported.",
        )

    def handle(self, *args, **options):
        fix = options["fix"]
        self.stdout.write(self.style.MIGRATE_HEADING("Branch integrity audit"))
        self.stdout.write("")

        self._report_counts()
        self.stdout.write("")
        fixed_students = self._audit_students(fix)
        self.stdout.write("")
        fixed_staff = self._audit_staff(fix)
        self.stdout.write("")
        self._report_groups_without_branch()

        if fix:
            self.stdout.write("")
            self.stdout.write(
                self.style.SUCCESS(
                    f"Fixed {fixed_students} student(s) and {fixed_staff} teacher(s)."
                )
            )

    # ── Per-branch counts ────────────────────────────────────────────────

    def _report_counts(self):
        self.stdout.write(self.style.HTTP_INFO("Per-branch counts"))
        groups = (
            Group.objects.values("branch__name").annotate(c=Count("id")).order_by("branch__name")
        )
        students = (
            Student.objects.values("branch__name").annotate(c=Count("id")).order_by("branch__name")
        )
        staff = (
            Staff.objects.values("branch__name").annotate(c=Count("id")).order_by("branch__name")
        )

        def fmt(rows):
            return ", ".join(f"{r['branch__name'] or '∅ (none)'}={r['c']}" for r in rows) or "—"

        self.stdout.write(f"  Students per branch: {fmt(students)}")
        self.stdout.write(f"  Teachers per branch: {fmt(staff)}")
        self.stdout.write(f"  Groups per branch:   {fmt(groups)}")

    # ── Students ─────────────────────────────────────────────────────────

    def _audit_students(self, fix):
        null_students = Student.objects.filter(branch__isnull=True)
        self.stdout.write(self.style.HTTP_INFO(f"Students with no branch: {null_students.count()}"))
        fixed = 0
        ambiguous = 0
        for student in null_students.select_related("admin"):
            branch_ids = set(
                Enrollment.objects.filter(
                    student=student, is_active=True, group__branch__isnull=False
                ).values_list("group__branch_id", flat=True)
            )
            if len(branch_ids) == 1:
                if fix:
                    student.branch_id = branch_ids.pop()
                    student.save(update_fields=["branch"])
                    fixed += 1
            elif len(branch_ids) > 1:
                ambiguous += 1
                self.stdout.write(
                    self.style.WARNING(
                        f"  AMBIGUOUS student #{student.id} ({student.admin.login_id or student.admin.email}): "
                        f"enrolled across branches {sorted(branch_ids)}"
                    )
                )

        # Students enrolled in groups from a different branch than their own.
        mismatched = (
            Enrollment.objects.filter(is_active=True, group__branch__isnull=False)
            .exclude(student__branch__isnull=True)
            .exclude(student__branch_id__isnull=True)
            .filter(student__branch__isnull=False)
        )
        cross = 0
        for e in mismatched.select_related("student__admin", "group__branch"):
            if (
                e.student.branch_id
                and e.group.branch_id
                and e.student.branch_id != e.group.branch_id
            ):
                cross += 1
                self.stdout.write(
                    self.style.WARNING(
                        f"  CROSS-BRANCH enrollment: student #{e.student_id} "
                        f"(branch {e.student.branch_id}) in group '{e.group.name}' "
                        f"(branch {e.group.branch_id})"
                    )
                )
        if cross:
            self.stdout.write(f"  Cross-branch enrollments: {cross}")
        if ambiguous and not fix:
            self.stdout.write(f"  ({ambiguous} ambiguous — re-run is needed after manual cleanup)")
        return fixed

    # ── Staff ────────────────────────────────────────────────────────────

    def _audit_staff(self, fix):
        null_staff = Staff.objects.filter(branch__isnull=True)
        self.stdout.write(self.style.HTTP_INFO(f"Teachers with no branch: {null_staff.count()}"))
        fixed = 0
        for staff in null_staff.select_related("admin"):
            branch_ids = set(
                Group.objects.filter(teacher=staff, branch__isnull=False).values_list(
                    "branch_id", flat=True
                )
            )
            if len(branch_ids) == 1:
                if fix:
                    staff.branch_id = branch_ids.pop()
                    staff.save(update_fields=["branch"])
                    fixed += 1
            elif len(branch_ids) > 1:
                self.stdout.write(
                    self.style.WARNING(
                        f"  AMBIGUOUS teacher #{staff.id} ({staff.admin.login_id or staff.admin.email}): "
                        f"teaches across branches {sorted(branch_ids)}"
                    )
                )

        # Teachers assigned to groups in a branch other than their own.
        cross = 0
        for group in Group.objects.filter(
            teacher__isnull=False, branch__isnull=False, teacher__branch__isnull=False
        ).select_related("teacher__admin"):
            if group.teacher.branch_id and group.teacher.branch_id != group.branch_id:
                cross += 1
                self.stdout.write(
                    self.style.WARNING(
                        f"  CROSS-BRANCH teacher: '{group.teacher.admin.email}' "
                        f"(branch {group.teacher.branch_id}) teaches group '{group.name}' "
                        f"(branch {group.branch_id})"
                    )
                )
        if cross:
            self.stdout.write(f"  Cross-branch teacher assignments: {cross}")
        return fixed

    # ── Groups ───────────────────────────────────────────────────────────

    def _report_groups_without_branch(self):
        null_groups = Group.objects.filter(branch__isnull=True)
        self.stdout.write(self.style.HTTP_INFO(f"Groups with no branch: {null_groups.count()}"))
        for group in null_groups[:50]:
            self.stdout.write(f"  Group #{group.id}: '{group.name}'")
