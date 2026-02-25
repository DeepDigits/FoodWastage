from django.db import models
from django.contrib.auth.models import AbstractUser
import os, uuid


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
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.title} by {self.donor.full_name}"
