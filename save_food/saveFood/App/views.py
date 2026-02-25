from rest_framework import status
from rest_framework.decorators import api_view, permission_classes, parser_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from rest_framework.parsers import MultiPartParser, FormParser
from django.contrib.auth import authenticate

from .serializers import SignupSerializer, LoginSerializer, UserSerializer, FoodDonationSerializer
from .models import DISTRICT_CHOICES, USER_TYPE_CHOICES, FoodDonation


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
