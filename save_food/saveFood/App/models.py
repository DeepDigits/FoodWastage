from django.db import models
from django.contrib.auth.models import AbstractUser
import os, uuid, random


DISTRICT_CHOICES = [
    ('thiruvananthapuram', 'Thiruvananthapuram'),
    ('kollam', 'Kollam'),
    ('pathanamthitta', 'Pathanamthitta'),
    ('alappuzha', 'Alappuzha'),
    ('kottayam', 'Kottayam'),
    ('idukki', 'Idukki'),
    ('ernakulam', 'Ernakulam'),
    ('thrissur', 'Thrissur'),
    ('palakkad', 'Palakkad'),
    ('malappuram', 'Malappuram'),
    ('kozhikode', 'Kozhikode'),
    ('wayanad', 'Wayanad'),
    ('kannur', 'Kannur'),
    ('kasaragod', 'Kasaragod'),
]

USER_TYPE_CHOICES = [
    ('citizen', 'Citizen'),
    ('restaurant', 'Restaurant'),
    ('organization', 'Organization'),
    ('collector', 'Food Waste Collector'),
]

FOOD_TYPE_CHOICES = [
    ('packed', 'Packed / Sealed Food'),
    ('homecooked', 'Home-Cooked Food'),
    ('organic', 'Organic / Raw Produce'),
]

FOOD_CATEGORY_CHOICES = [
    ('edible', 'Edible'),
    ('recyclable', 'Recyclable'),
    ('rejected', 'Rejected'),
]


def food_image_path(instance, filename):
    ext = filename.rsplit('.', 1)[-1]
    return os.path.join('food_donations', f'{uuid.uuid4().hex}.{ext}')


class CustomUser(AbstractUser):
    full_name = models.CharField(max_length=150)
    phone = models.CharField(max_length=10, unique=True)
    pin_code = models.CharField(max_length=6)
    district = models.CharField(max_length=50, choices=DISTRICT_CHOICES)
    full_address = models.TextField(blank=True)
    user_type = models.CharField(max_length=20, choices=USER_TYPE_CHOICES, default='citizen')

    def __str__(self):
        return f"{self.full_name} ({self.username})"


class FoodDonation(models.Model):
    donor = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='donations')
    title = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    food_type = models.CharField(max_length=20, choices=FOOD_TYPE_CHOICES)
    category = models.CharField(max_length=20, choices=FOOD_CATEGORY_CHOICES, default='edible')
    image = models.ImageField(upload_to=food_image_path)
    latitude = models.FloatField()
    longitude = models.FloatField()
    address = models.TextField(blank=True)
    expiry_date = models.DateField(null=True, blank=True)
    safety_hours = models.PositiveIntegerField(null=True, blank=True,
        help_text='Hours within which home-cooked food is safe')
    gemini_analysis = models.JSONField(default=dict, blank=True,
        help_text='Full Gemini AI analysis result')
    is_safe = models.BooleanField(default=True)
    is_sold = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.title} by {self.donor.full_name}"


REQUEST_STATUS_CHOICES = [
    ('pending', 'Pending'),
    ('accepted', 'Accepted'),
    ('rejected', 'Rejected'),
]

DELIVERY_STATUS_CHOICES = [
    ('waiting', 'Waiting for Pickup'),
    ('collected', 'Collected from Donor'),
    ('delivered', 'Delivered to Requester'),
]


class FoodWasteCollector(models.Model):
    """Food waste collectors managed by admin via Django admin panel."""
    user = models.OneToOneField(
        CustomUser, on_delete=models.CASCADE, related_name='collector_profile'
    )
    employee_id = models.CharField(max_length=20, unique=True)
    vehicle_number = models.CharField(max_length=20, blank=True)
    zone = models.CharField(max_length=100, blank=True,
        help_text='Area/zone assigned for collection')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.full_name} ({self.employee_id})"


def _generate_otp():
    return str(random.randint(100000, 999999))


class BuyRequest(models.Model):
    """A buy request from a user wanting to acquire a donated food item."""
    requester = models.ForeignKey(
        CustomUser, on_delete=models.CASCADE, related_name='sent_requests'
    )
    donation = models.ForeignKey(
        FoodDonation, on_delete=models.CASCADE, related_name='buy_requests'
    )
    status = models.CharField(
        max_length=10, choices=REQUEST_STATUS_CHOICES, default='pending'
    )
    message = models.TextField(blank=True)

    # OTP fields – generated when request is accepted
    sender_otp = models.CharField(max_length=6, blank=True,
        help_text='OTP for the food donor (sender)')
    receiver_otp = models.CharField(max_length=6, blank=True,
        help_text='OTP for the food requester (receiver)')

    # Delivery tracking
    delivery_status = models.CharField(
        max_length=12, choices=DELIVERY_STATUS_CHOICES,
        default='waiting', blank=True
    )
    assigned_collector = models.ForeignKey(
        FoodWasteCollector, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='assigned_requests',
        help_text='Collector assigned by admin'
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        unique_together = ['requester', 'donation']

    def generate_otps(self):
        """Generate random OTPs for both sender and receiver."""
        self.sender_otp = _generate_otp()
        self.receiver_otp = _generate_otp()
        self.save()

    def __str__(self):
        return f"Request by {self.requester.full_name} for {self.donation.title} ({self.status})"
