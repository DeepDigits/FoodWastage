from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import CustomUser, FoodDonation, BuyRequest, FoodWasteCollector


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


@admin.register(FoodDonation)
class FoodDonationAdmin(admin.ModelAdmin):
    list_display = ('title', 'donor', 'food_type', 'category', 'is_safe', 'is_sold', 'created_at')
    list_filter = ('food_type', 'category', 'is_safe', 'is_sold')
    search_fields = ('title', 'description', 'donor__full_name')
    readonly_fields = ('created_at', 'updated_at')


@admin.register(FoodWasteCollector)
class FoodWasteCollectorAdmin(admin.ModelAdmin):
    list_display = ('user', 'employee_id', 'vehicle_number', 'zone', 'is_active', 'created_at')
    list_filter = ('is_active', 'zone')
    search_fields = ('user__full_name', 'employee_id', 'vehicle_number')
    raw_id_fields = ('user',)

    def save_model(self, request, obj, form, change):
        """Ensure the linked user has user_type = 'collector' for API identification."""
        super().save_model(request, obj, form, change)
        if obj.user.user_type != 'collector':
            obj.user.user_type = 'collector'
            obj.user.save()


@admin.register(BuyRequest)
class BuyRequestAdmin(admin.ModelAdmin):
    list_display = ('id', 'requester', 'donation', 'status', 'delivery_status',
                    'assigned_collector', 'sender_otp', 'receiver_otp', 'created_at')
    list_filter = ('status', 'delivery_status', 'assigned_collector')
    search_fields = ('requester__full_name', 'donation__title')
    raw_id_fields = ('requester', 'donation', 'assigned_collector')
    readonly_fields = ('sender_otp', 'receiver_otp', 'created_at', 'updated_at')
    list_editable = ('assigned_collector',)
