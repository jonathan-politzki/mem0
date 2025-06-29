"""
Profile management router
Handles user profile data, phone number verification, and SMS settings
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel, validator
from typing import Optional
import re
import logging

from app.database import get_db
from app.auth import get_current_supa_user
from gotrue.types import User as SupabaseUser
from app.utils.db import get_or_create_user
from app.models import User, SubscriptionTier
from app.middleware.subscription_middleware import SubscriptionChecker
from app.utils.sms import SMSService, SMSVerification, SMSRateLimit, sms_config

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/profile", tags=["profile"])

# Pydantic models for request/response
class ProfileResponse(BaseModel):
    user_id: str
    email: Optional[str]
    name: Optional[str]
    subscription_tier: str
    phone_number: Optional[str]
    phone_verified: bool
    sms_enabled: bool
    
    class Config:
        from_attributes = True

class PhoneNumberRequest(BaseModel):
    phone_number: str
    
    @validator('phone_number')
    def validate_phone_number(cls, v):
        # Remove common formatting characters
        cleaned = re.sub(r'[^\d+]', '', v)
        
        # Check if it's a valid US phone number format
        if cleaned.startswith('+1'):
            cleaned = cleaned[2:]
        elif cleaned.startswith('1'):
            cleaned = cleaned[1:]
        
        if len(cleaned) != 10:
            raise ValueError('Phone number must be a valid 10-digit US number')
        
        # Return in E.164 format
        return f"+1{cleaned}"

class VerificationCodeRequest(BaseModel):
    verification_code: str
    
    @validator('verification_code')
    def validate_code(cls, v):
        if not re.match(r'^\d{6}$', v):
            raise ValueError('Verification code must be 6 digits')
        return v

class SMSSettingsRequest(BaseModel):
    sms_enabled: bool

# Profile endpoints
@router.get("", response_model=ProfileResponse)
async def get_profile(
    current_supa_user: SupabaseUser = Depends(get_current_supa_user),
    db: Session = Depends(get_db)
):
    """Get user profile information including SMS settings"""
    supabase_user_id_str = str(current_supa_user.id)
    user = get_or_create_user(db, supabase_user_id_str, current_supa_user.email)
    
    return ProfileResponse(
        user_id=user.user_id,
        email=user.email,
        name=user.name,
        subscription_tier=user.subscription_tier.value,
        phone_number=user.phone_number,
        phone_verified=user.phone_verified or False,
        sms_enabled=user.sms_enabled if user.sms_enabled is not None else True
    )

@router.post("/phone/add")
async def add_phone_number(
    request: PhoneNumberRequest,
    current_supa_user: SupabaseUser = Depends(get_current_supa_user),
    db: Session = Depends(get_db)
):
    """Add and verify phone number (Pro feature)"""
    supabase_user_id_str = str(current_supa_user.id)
    user = get_or_create_user(db, supabase_user_id_str, current_supa_user.email)
    
    # Check if user has Pro subscription
    try:
        SubscriptionChecker.check_pro_features(user, "SMS integration")
    except HTTPException as e:
        raise e
    
    # Check if SMS is configured
    if not sms_config.is_configured:
        raise HTTPException(
            status_code=503, 
            detail="SMS service is not available at this time"
        )
    
    # Check verification attempts to prevent abuse
    if user.phone_verification_attempts and user.phone_verification_attempts >= 5:
        raise HTTPException(
            status_code=429,
            detail="Too many verification attempts. Please try again later."
        )
    
    # Check if phone number is already taken by another user
    existing_user = db.query(User).filter(
        User.phone_number == request.phone_number,
        User.id != user.id
    ).first()
    
    if existing_user:
        raise HTTPException(
            status_code=409,
            detail="This phone number is already registered to another account"
        )
    
    # Generate and send verification code
    verification_code = SMSVerification.generate_verification_code()
    
    # Store verification code
    if not SMSVerification.store_verification_code(user, verification_code, db):
        raise HTTPException(
            status_code=500,
            detail="Failed to store verification code"
        )
    
    # Send SMS
    sms_service = SMSService()
    if not sms_service.send_verification_code(request.phone_number, verification_code):
        raise HTTPException(
            status_code=500,
            detail="Failed to send verification code"
        )
    
    # Update user with phone number and increment attempts
    user.phone_number = request.phone_number
    user.phone_verified = False
    user.phone_verification_attempts = (user.phone_verification_attempts or 0) + 1
    
    try:
        db.commit()
    except Exception as e:
        db.rollback()
        logger.error(f"Failed to update user phone number: {e}")
        raise HTTPException(status_code=500, detail="Database error")
    
    return {
        "message": "Verification code sent to your phone",
        "phone_number": request.phone_number,
        "expires_in_minutes": sms_config.SMS_VERIFICATION_TIMEOUT // 60
    }

@router.post("/phone/verify")
async def verify_phone_number(
    request: VerificationCodeRequest,
    current_supa_user: SupabaseUser = Depends(get_current_supa_user),
    db: Session = Depends(get_db)
):
    """Verify phone number with code"""
    supabase_user_id_str = str(current_supa_user.id)
    user = get_or_create_user(db, supabase_user_id_str, current_supa_user.email)
    
    # Check if user has Pro subscription
    try:
        SubscriptionChecker.check_pro_features(user, "SMS integration")
    except HTTPException as e:
        raise e
    
    if not user.phone_number:
        raise HTTPException(
            status_code=400,
            detail="No phone number to verify. Please add a phone number first."
        )
    
    # Verify the code
    if SMSVerification.verify_code(user, request.verification_code, db):
        # Reset verification attempts on success
        user.phone_verification_attempts = 0
        user.sms_enabled = True
        db.commit()
        
        return {
            "message": "Phone number verified successfully",
            "phone_number": user.phone_number,
            "verified": True
        }
    else:
        raise HTTPException(
            status_code=400,
            detail="Invalid or expired verification code"
        )

@router.delete("/phone")
async def remove_phone_number(
    current_supa_user: SupabaseUser = Depends(get_current_supa_user),
    db: Session = Depends(get_db)
):
    """Remove phone number from account"""
    supabase_user_id_str = str(current_supa_user.id)
    user = get_or_create_user(db, supabase_user_id_str, current_supa_user.email)
    
    # Clear phone-related fields
    user.phone_number = None
    user.phone_verified = False
    user.phone_verification_attempts = 0
    user.phone_verified_at = None
    user.sms_enabled = False
    
    # Clean up any pending verification in metadata
    if user.metadata_ and 'sms_verification' in user.metadata_:
        del user.metadata_['sms_verification']
    
    try:
        db.commit()
    except Exception as e:
        db.rollback()
        logger.error(f"Failed to remove phone number: {e}")
        raise HTTPException(status_code=500, detail="Database error")
    
    return {"message": "Phone number removed successfully"}

@router.put("/sms/settings")
async def update_sms_settings(
    request: SMSSettingsRequest,
    current_supa_user: SupabaseUser = Depends(get_current_supa_user),
    db: Session = Depends(get_db)
):
    """Update SMS notification settings"""
    supabase_user_id_str = str(current_supa_user.id)
    user = get_or_create_user(db, supabase_user_id_str, current_supa_user.email)
    
    if not user.phone_verified:
        raise HTTPException(
            status_code=400,
            detail="Phone number must be verified before changing SMS settings"
        )
    
    user.sms_enabled = request.sms_enabled
    
    try:
        db.commit()
    except Exception as e:
        db.rollback()
        logger.error(f"Failed to update SMS settings: {e}")
        raise HTTPException(status_code=500, detail="Database error")
    
    return {
        "message": "SMS settings updated successfully",
        "sms_enabled": user.sms_enabled
    }

@router.get("/sms/usage")
async def get_sms_usage(
    current_supa_user: SupabaseUser = Depends(get_current_supa_user),
    db: Session = Depends(get_db)
):
    """Get SMS usage statistics"""
    supabase_user_id_str = str(current_supa_user.id)
    user = get_or_create_user(db, supabase_user_id_str, current_supa_user.email)
    
    # Check if user has Pro subscription
    try:
        SubscriptionChecker.check_pro_features(user, "SMS integration")
    except HTTPException as e:
        raise e
    
    # Get rate limits and current usage
    allowed, remaining = SMSRateLimit.check_rate_limit(user, db)
    
    # Get limit based on subscription tier
    if user.subscription_tier == SubscriptionTier.ENTERPRISE:
        daily_limit = sms_config.SMS_RATE_LIMIT_ENTERPRISE
    elif user.subscription_tier == SubscriptionTier.PRO:
        daily_limit = sms_config.SMS_RATE_LIMIT_PRO
    else:
        daily_limit = 0
    
    used_today = daily_limit - remaining if allowed else daily_limit
    
    return {
        "daily_limit": daily_limit,
        "used_today": used_today,
        "remaining_today": remaining,
        "subscription_tier": user.subscription_tier.value,
        "phone_verified": user.phone_verified or False,
        "sms_enabled": user.sms_enabled if user.sms_enabled is not None else True
    } 