from rest_framework import serializers
from .models import CustomUser, FoodDonation, BuyRequest, FoodWasteCollector
import re


class SignupSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)
    confirm_password = serializers.CharField(write_only=True)

    class Meta:
        model = CustomUser
        fields = [
            'username', 'email', 'password', 'confirm_password',
            'full_name', 'phone', 'pin_code', 'district',
            'full_address', 'user_type',
        ]

    def validate_full_name(self, value):
        if not re.match(r'^[a-zA-Z\s]+$', value):
            raise serializers.ValidationError(
                "Full name should only contain letters and spaces."
            )
        if len(value.strip()) < 2:
            raise serializers.ValidationError(
                "Full name must be at least 2 characters."
            )
        return value.strip()

    def validate_phone(self, value):
        if not re.match(r'^\d{10}$', value):
            raise serializers.ValidationError(
                "Phone number must be exactly 10 digits."
            )
        return value

    def validate_pin_code(self, value):
        if not re.match(r'^\d{6}$', value):
            raise serializers.ValidationError(
                "Pin code must be exactly 6 digits."
            )
        return value

    def validate_email(self, value):
        if CustomUser.objects.filter(email=value).exists():
            raise serializers.ValidationError(
                "A user with this email already exists."
            )
        return value

    def validate(self, data):
        if data['password'] != data['confirm_password']:
            raise serializers.ValidationError({
                'confirm_password': "Passwords do not match."
            })
        return data

    def create(self, validated_data):
        validated_data.pop('confirm_password')
        password = validated_data.pop('password')
        user = CustomUser(**validated_data)
        user.set_password(password)
        user.save()
        return user


class LoginSerializer(serializers.Serializer):
    username = serializers.CharField()
    password = serializers.CharField()


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = CustomUser
        fields = [
            'id', 'username', 'email', 'full_name', 'phone',
            'pin_code', 'district', 'full_address', 'user_type',
        ]


class FoodDonationSerializer(serializers.ModelSerializer):
    donor_name = serializers.CharField(source='donor.full_name', read_only=True)
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = FoodDonation
        fields = [
            'id', 'donor', 'donor_name', 'title', 'description',
            'food_type', 'category', 'image', 'image_url',
            'latitude', 'longitude', 'address',
            'expiry_date', 'safety_hours', 'gemini_analysis',
            'is_safe', 'is_sold', 'created_at',
        ]
        read_only_fields = ['donor', 'donor_name', 'created_at']

    def get_image_url(self, obj):
        request = self.context.get('request')
        if obj.image and request:
            return request.build_absolute_uri(obj.image.url)
        return None


class BuyRequestSerializer(serializers.ModelSerializer):
    requester_name = serializers.CharField(source='requester.full_name', read_only=True)
    requester_phone = serializers.CharField(source='requester.phone', read_only=True)
    requester_address = serializers.CharField(source='requester.full_address', read_only=True)
    requester_district = serializers.CharField(source='requester.district', read_only=True)
    donation_title = serializers.CharField(source='donation.title', read_only=True)
    donation_image_url = serializers.SerializerMethodField()
    donor_id = serializers.IntegerField(source='donation.donor.id', read_only=True)
    donor_name = serializers.CharField(source='donation.donor.full_name', read_only=True)
    donation_data = serializers.SerializerMethodField()
    collector_name = serializers.SerializerMethodField()

    class Meta:
        model = BuyRequest
        fields = [
            'id', 'requester', 'requester_name', 'requester_phone',
            'requester_address', 'requester_district',
            'donation', 'donation_title', 'donation_image_url',
            'donor_id', 'donor_name', 'donation_data',
            'status', 'message',
            'sender_otp', 'receiver_otp',
            'delivery_status', 'collector_name',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['requester', 'status', 'created_at', 'updated_at']

    def get_donation_image_url(self, obj):
        request = self.context.get('request')
        if obj.donation.image and request:
            return request.build_absolute_uri(obj.donation.image.url)
        return None

    def get_donation_data(self, obj):
        request = self.context.get('request')
        return FoodDonationSerializer(obj.donation, context={'request': request}).data

    def get_collector_name(self, obj):
        if obj.assigned_collector:
            return obj.assigned_collector.user.full_name
        return None


class CollectorSerializer(serializers.ModelSerializer):
    full_name = serializers.CharField(source='user.full_name', read_only=True)
    phone = serializers.CharField(source='user.phone', read_only=True)
    district = serializers.CharField(source='user.district', read_only=True)
    user_id = serializers.IntegerField(source='user.id', read_only=True)

    class Meta:
        model = FoodWasteCollector
        fields = [
            'id', 'user_id', 'full_name', 'phone', 'district',
            'employee_id', 'vehicle_number', 'zone', 'is_active',
        ]
