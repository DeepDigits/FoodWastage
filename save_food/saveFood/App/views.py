from rest_framework import status
from rest_framework.decorators import api_view, permission_classes, parser_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from rest_framework.parsers import MultiPartParser, FormParser
from django.contrib.auth import authenticate

from .serializers import (
    SignupSerializer, LoginSerializer, UserSerializer,
    FoodDonationSerializer, BuyRequestSerializer, CollectorSerializer,
)
from .models import (
    DISTRICT_CHOICES, USER_TYPE_CHOICES, FoodDonation, BuyRequest,
    FoodWasteCollector,
)


@api_view(['POST'])
@permission_classes([AllowAny])
def signup_view(request):
    serializer = SignupSerializer(data=request.data)
    if serializer.is_valid():
        user = serializer.save()
        token, _ = Token.objects.get_or_create(user=user)
        return Response({
            'token': token.key,
            'user': UserSerializer(user).data,
            'message': 'Account created successfully.',
        }, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([AllowAny])
def login_view(request):
    serializer = LoginSerializer(data=request.data)
    if serializer.is_valid():
        user = authenticate(
            username=serializer.validated_data['username'],
            password=serializer.validated_data['password'],
        )
        if user:
            token, _ = Token.objects.get_or_create(user=user)
            return Response({
                'token': token.key,
                'user': UserSerializer(user).data,
                'message': 'Login successful.',
            })
        return Response(
            {'non_field_errors': ['Invalid username or password.']},
            status=status.HTTP_401_UNAUTHORIZED,
        )
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def profile_view(request):
    return Response(UserSerializer(request.user).data)


@api_view(['GET'])
@permission_classes([AllowAny])
def districts_view(request):
    return Response([
        {'value': d[0], 'label': d[1]} for d in DISTRICT_CHOICES
    ])


@api_view(['GET'])
@permission_classes([AllowAny])
def user_types_view(request):
    return Response([
        {'value': u[0], 'label': u[1]} for u in USER_TYPE_CHOICES
    ])


# ── Food Donation Views ──────────────────────────────────────────

@api_view(['POST'])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser])
def donate_food_view(request):
    """Create a new food donation."""
    serializer = FoodDonationSerializer(data=request.data, context={'request': request})
    if serializer.is_valid():
        serializer.save(donor=request.user)
        return Response({
            'message': 'Food donated successfully!',
            'donation': serializer.data,
        }, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['GET'])
@permission_classes([AllowAny])
def donations_list_view(request):
    """List all safe donations (for the explore/homepage feed)."""
    donations = FoodDonation.objects.filter(is_safe=True).order_by('-created_at')
    serializer = FoodDonationSerializer(donations, many=True, context={'request': request})
    return Response(serializer.data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def my_donations_view(request):
    """List the authenticated user's donations."""
    donations = FoodDonation.objects.filter(donor=request.user).order_by('-created_at')
    serializer = FoodDonationSerializer(donations, many=True, context={'request': request})
    return Response(serializer.data)


# ── Buy Request Views ────────────────────────────────────────────

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_buy_request_view(request):
    """Send a buy request for a donation."""
    donation_id = request.data.get('donation')
    if not donation_id:
        return Response({'error': 'donation field is required.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        donation = FoodDonation.objects.get(id=donation_id)
    except FoodDonation.DoesNotExist:
        return Response({'error': 'Donation not found.'}, status=status.HTTP_404_NOT_FOUND)

    if donation.donor == request.user:
        return Response({'error': 'You cannot request your own donation.'}, status=status.HTTP_400_BAD_REQUEST)

    if donation.is_sold:
        return Response({'error': 'This item has already been sold.'}, status=status.HTTP_400_BAD_REQUEST)

    if BuyRequest.objects.filter(requester=request.user, donation=donation).exists():
        return Response({'error': 'You have already sent a request for this item.'}, status=status.HTTP_400_BAD_REQUEST)

    buy_request = BuyRequest.objects.create(
        requester=request.user,
        donation=donation,
        message=request.data.get('message', ''),
    )
    serializer = BuyRequestSerializer(buy_request, context={'request': request})
    return Response({
        'message': 'Buy request sent successfully!',
        'request': serializer.data,
    }, status=status.HTTP_201_CREATED)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def sent_requests_view(request):
    """List buy requests sent by the current user."""
    requests_qs = BuyRequest.objects.filter(requester=request.user).order_by('-created_at')
    serializer = BuyRequestSerializer(requests_qs, many=True, context={'request': request})
    return Response(serializer.data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def received_requests_view(request):
    """List buy requests received for the current user's donations."""
    requests_qs = BuyRequest.objects.filter(
        donation__donor=request.user
    ).order_by('-created_at')
    serializer = BuyRequestSerializer(requests_qs, many=True, context={'request': request})
    return Response(serializer.data)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def respond_buy_request_view(request, pk):
    """Accept or reject a buy request. Only the donation owner can respond."""
    try:
        buy_request = BuyRequest.objects.get(id=pk)
    except BuyRequest.DoesNotExist:
        return Response({'error': 'Request not found.'}, status=status.HTTP_404_NOT_FOUND)

    if buy_request.donation.donor != request.user:
        return Response({'error': 'Only the donation owner can respond.'}, status=status.HTTP_403_FORBIDDEN)

    action = request.data.get('action')  # 'accept' or 'reject'
    if action not in ('accept', 'reject'):
        return Response({'error': "action must be 'accept' or 'reject'."}, status=status.HTTP_400_BAD_REQUEST)

    if action == 'accept':
        buy_request.status = 'accepted'
        buy_request.delivery_status = 'waiting'
        buy_request.save()
        # Generate OTPs for sender and receiver
        buy_request.generate_otps()
        # Mark the donation as sold
        buy_request.donation.is_sold = True
        buy_request.donation.save()
        # Reject all other pending requests for this donation
        BuyRequest.objects.filter(
            donation=buy_request.donation, status='pending'
        ).exclude(id=buy_request.id).update(status='rejected')
    else:
        buy_request.status = 'rejected'
        buy_request.save()

    serializer = BuyRequestSerializer(buy_request, context={'request': request})
    return Response({
        'message': f'Request {action}ed successfully.',
        'request': serializer.data,
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def check_buy_request_view(request, donation_id):
    """Check if the current user has already sent a buy request for this donation."""
    exists = BuyRequest.objects.filter(
        requester=request.user, donation_id=donation_id
    ).first()
    if exists:
        return Response({
            'has_request': True,
            'status': exists.status,
            'request_id': exists.id,
            'delivery_status': exists.delivery_status,
            'sender_otp': exists.sender_otp,
            'receiver_otp': exists.receiver_otp,
        })
    return Response({'has_request': False})


# ── Collector Views ──────────────────────────────────────────────

@api_view(['POST'])
@permission_classes([AllowAny])
def collector_login_view(request):
    """Login endpoint for food waste collectors."""
    username = request.data.get('username')
    password = request.data.get('password')
    if not username or not password:
        return Response({'error': 'Username and password are required.'},
                        status=status.HTTP_400_BAD_REQUEST)

    user = authenticate(username=username, password=password)
    if not user:
        return Response({'error': 'Invalid credentials.'},
                        status=status.HTTP_401_UNAUTHORIZED)

    # Check if user is a collector
    try:
        collector = FoodWasteCollector.objects.get(user=user)
    except FoodWasteCollector.DoesNotExist:
        return Response({'error': 'You are not registered as a food waste collector.'},
                        status=status.HTTP_403_FORBIDDEN)

    if not collector.is_active:
        return Response({'error': 'Your collector account is deactivated.'},
                        status=status.HTTP_403_FORBIDDEN)

    token, _ = Token.objects.get_or_create(user=user)
    return Response({
        'token': token.key,
        'user': UserSerializer(user).data,
        'collector': CollectorSerializer(collector).data,
        'message': 'Collector login successful.',
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def collector_dashboard_view(request):
    """Get accepted requests assigned to the current collector."""
    try:
        collector = FoodWasteCollector.objects.get(user=request.user)
    except FoodWasteCollector.DoesNotExist:
        return Response({'error': 'Not a collector.'}, status=status.HTTP_403_FORBIDDEN)

    assigned = BuyRequest.objects.filter(
        assigned_collector=collector,
        status='accepted',
    ).order_by('-created_at')

    serializer = BuyRequestSerializer(assigned, many=True, context={'request': request})
    return Response(serializer.data)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def collector_verify_otp_view(request, pk):
    """Collector verifies OTP: sender_otp → collected, receiver_otp → delivered."""
    try:
        collector = FoodWasteCollector.objects.get(user=request.user)
    except FoodWasteCollector.DoesNotExist:
        return Response({'error': 'Not a collector.'}, status=status.HTTP_403_FORBIDDEN)

    try:
        buy_request = BuyRequest.objects.get(id=pk, assigned_collector=collector)
    except BuyRequest.DoesNotExist:
        return Response({'error': 'Request not found or not assigned to you.'},
                        status=status.HTTP_404_NOT_FOUND)

    otp = request.data.get('otp', '').strip()
    if not otp:
        return Response({'error': 'OTP is required.'}, status=status.HTTP_400_BAD_REQUEST)

    if buy_request.delivery_status == 'delivered':
        return Response({'error': 'This request is already delivered.'},
                        status=status.HTTP_400_BAD_REQUEST)

    if buy_request.delivery_status == 'waiting' and otp == buy_request.sender_otp:
        buy_request.delivery_status = 'collected'
        buy_request.save()
        serializer = BuyRequestSerializer(buy_request, context={'request': request})
        return Response({
            'message': 'Food collected from donor! OTP verified.',
            'delivery_status': 'collected',
            'request': serializer.data,
        })
    elif buy_request.delivery_status == 'collected' and otp == buy_request.receiver_otp:
        buy_request.delivery_status = 'delivered'
        buy_request.save()
        serializer = BuyRequestSerializer(buy_request, context={'request': request})
        return Response({
            'message': 'Food delivered to requester! OTP verified.',
            'delivery_status': 'delivered',
            'request': serializer.data,
        })
    else:
        expected = 'sender' if buy_request.delivery_status == 'waiting' else 'receiver'
        return Response({
            'error': f'Invalid OTP. Please enter the {expected} OTP.',
        }, status=status.HTTP_400_BAD_REQUEST)
