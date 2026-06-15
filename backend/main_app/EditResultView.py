from django.contrib.auth.mixins import LoginRequiredMixin
from django.shortcuts import get_object_or_404, render
from django.views import View
from django.contrib import messages
from .models import Group, Staff, Student, StudentResult


class EditResultView(LoginRequiredMixin, View):
    template = "staff_template/edit_student_result.html"

    def _staff_and_groups(self, request):
        staff = get_object_or_404(Staff, admin=request.user)
        return staff, Group.objects.filter(teacher=staff, is_archived=False)

    def get(self, request, *args, **kwargs):
        _staff, groups = self._staff_and_groups(request)
        return render(
            request,
            self.template,
            {
                "groups": groups,
                "page_title": "Edit Student Result",
            },
        )

    def post(self, request, *args, **kwargs):
        staff, groups = self._staff_and_groups(request)
        group_id = request.POST.get("group")
        student_id = request.POST.get("student")
        test = request.POST.get("test")
        exam = request.POST.get("exam")

        # Restrict to groups owned by this teacher (raises Http404 on violation).
        group = get_object_or_404(groups, id=group_id)
        student = get_object_or_404(Student, id=student_id)

        try:
            test_val = float(test)
            exam_val = float(exam)
            if not (
                0 <= test_val <= StudentResult.TEST_MAX and 0 <= exam_val <= StudentResult.EXAM_MAX
            ):
                messages.warning(
                    request,
                    f"Scores out of range: test must be 0–{StudentResult.TEST_MAX}, "
                    f"exam 0–{StudentResult.EXAM_MAX}.",
                )
            else:
                result = StudentResult.objects.get(student=student, group=group)
                result.test = test_val
                result.exam = exam_val
                result.save()
                messages.success(request, "Result updated successfully.")
        except StudentResult.DoesNotExist:
            messages.warning(request, "No result found for this student in the selected group.")
        except (ValueError, TypeError) as e:
            messages.warning(request, f"Could not update: {e}")

        return render(
            request,
            self.template,
            {
                "groups": groups,
                "page_title": "Edit Student Result",
            },
        )
