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
    # Buy requests
    path('buy-request/', views.send_buy_request_view, name='send-buy-request'),
    path('buy-requests/sent/', views.sent_requests_view, name='sent-requests'),
    path('buy-requests/received/', views.received_requests_view, name='received-requests'),
    path('buy-requests/<int:pk>/respond/', views.respond_buy_request_view, name='respond-buy-request'),
    path('buy-requests/check/<int:donation_id>/', views.check_buy_request_view, name='check-buy-request'),
    # Collector
    path('collector/login/', views.collector_login_view, name='collector-login'),
    path('collector/dashboard/', views.collector_dashboard_view, name='collector-dashboard'),
    path('collector/verify-otp/<int:pk>/', views.collector_verify_otp_view, name='collector-verify-otp'),
]
