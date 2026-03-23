from sqlalchemy import Column, Integer, String, Float, ForeignKey, Boolean, BigInteger, UniqueConstraint
from sqlalchemy.orm import relationship
from app.database.database import Base

class Message(Base):
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True, index=True)
    sender_id = Column(Integer, ForeignKey("users.id"))
    receiver_id = Column(Integer, ForeignKey("users.id"), nullable=True) # Null for broadcast/group
    
    content = Column(String)
    type = Column(String) # 'text', 'image', 'sos', 'feedback', 'question'
    timestamp = Column(BigInteger)
    is_read = Column(Boolean, default=False)
    
    sender_hike_id = Column(Integer, ForeignKey("hiking_records.id"), nullable=True)
    receiver_hike_id = Column(Integer, ForeignKey("hiking_records.id"), nullable=True)
    
    sender = relationship("User", foreign_keys=[sender_id])
    receiver = relationship("User", foreign_keys=[receiver_id])


class FriendMessage(Base):
    """好友间消息：仅保存两人成为好友后的对话（文字、图片、emoji 等）。"""
    __tablename__ = "friend_messages"

    id = Column(Integer, primary_key=True, index=True)
    sender_id = Column(Integer, ForeignKey("users.id"))
    receiver_id = Column(Integer, ForeignKey("users.id"))

    content = Column(String)  # 文本内容或 emoji
    type = Column(String, default="text")  # text, image, emoji
    attachment_url = Column(String, nullable=True)  # 图片等附件的 URL
    timestamp = Column(BigInteger)
    is_read = Column(Boolean, default=False)

    sender = relationship("User", foreign_keys=[sender_id])
    receiver = relationship("User", foreign_keys=[receiver_id])


class TempFriendship(Base):
    """临时会话关系：仅用于非好友期间的临时沟通会话列表。"""
    __tablename__ = "temp_friendships"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    partner_id = Column(Integer, ForeignKey("users.id"), index=True)
    last_message = Column(String, nullable=True)
    last_message_type = Column(String, default="text")
    last_timestamp = Column(BigInteger)
    created_at = Column(BigInteger)
    updated_at = Column(BigInteger)

    __table_args__ = (
        UniqueConstraint("user_id", "partner_id", name="uq_temp_friendship_user_partner"),
    )

    user = relationship("User", foreign_keys=[user_id])
    partner = relationship("User", foreign_keys=[partner_id])


class Feedback(Base):
    __tablename__ = "feedbacks"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    
    type = Column(String) # 'blocked', 'weather', etc.
    content = Column(String)
    latitude = Column(Float)
    longitude = Column(Float)
    address = Column(String)
    photos = Column(String, nullable=True) # JSON list of URLs
    
    created_at = Column(BigInteger)
    status = Column(String, default='ACTIVE') # ACTIVE, EXPIRED
    
    view_count = Column(Integer, default=0)
    confirm_count = Column(Integer, default=0)
    forward_count = Column(Integer, default=0)
    
    user = relationship("User", back_populates="feedbacks")

class SOSAlert(Base):
    __tablename__ = "sos_alerts"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    latitude = Column(Float)
    longitude = Column(Float)
    message = Column(String)
    photos = Column(String, nullable=True)  # JSON list of base64 strings (临时存DB，后续可换成URL列表)
    status = Column(String, default='ACTIVE') # ACTIVE, RESOLVED
    created_at = Column(BigInteger)
    resolved_at = Column(BigInteger, nullable=True)
    
    user = relationship("User")


class FeedbackConfirm(Base):
    __tablename__ = "feedback_confirms"

    id = Column(Integer, primary_key=True, index=True)
    feedback_id = Column(Integer, ForeignKey("feedbacks.id"), index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    created_at = Column(BigInteger)

    __table_args__ = (
        UniqueConstraint("feedback_id", "user_id", name="uq_feedback_user_confirm"),
    )

    feedback = relationship("Feedback")
    user = relationship("User")


class FeedbackComment(Base):
    __tablename__ = "feedback_comments"

    id = Column(Integer, primary_key=True, index=True)
    feedback_id = Column(Integer, ForeignKey("feedbacks.id"), index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    content = Column(String)
    created_at = Column(BigInteger)

    feedback = relationship("Feedback")
    user = relationship("User")
