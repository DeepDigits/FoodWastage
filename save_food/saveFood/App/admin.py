from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import CustomUser


@admin.register(CustomUser)
class CustomUserAdmin(UserAdmin):
    list_display = ('username', 'full_name', 'email', 'phone', 'district', 'user_type', 'is_active')
    list_filter = ('user_type', 'district', 'is_active')
    search_fields = ('username', 'full_name', 'email', 'phone')
    fieldsets = UserAdmin.fieldsets + (
        ('Profile', {'fields': ('full_name', 'phone', 'pin_code', 'district', 'full_address', 'user_type')}),
    )
    add_fieldsets = UserAdmin.add_fieldsets + (
        ('Profile', {'fields': ('full_name', 'phone', 'pin_code', 'district', 'full_address', 'user_type')}),
    )
