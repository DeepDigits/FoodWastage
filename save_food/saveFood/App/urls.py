from django.urls import path
from . import views

urlpatterns = [
    path('signup/', views.signup_view, name='signup'),
    path('login/', views.login_view, name='login'),
    path('profile/', views.profile_view, name='profile'),
    path('districts/', views.districts_view, name='districts'),
    path('user-types/', views.user_types_view, name='user-types'),
    # Food donations
    path('donate/', views.donate_food_view, name='donate-food'),
    path('donations/', views.donations_list_view, name='donations-list'),
    path('my-donations/', views.my_donations_view, name='my-donations'),
]
