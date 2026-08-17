from unittest.mock import MagicMock, patch
from uuid import uuid4
from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.database import get_db
from app.main import app
from app.models.db_models import AIChatMessage, ChatAttachment


@pytest.fixture(autouse=True)
def _clear_overrides():
    yield
    app.dependency_overrides.clear()


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def mock_db():
    return MagicMock()


@pytest.fixture
def mock_user():
    user = MagicMock()
    user.id = uuid4()
    return user


@pytest.fixture(autouse=True)
def _setup_overrides(mock_db, mock_user):
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: mock_user
    yield


def _make_message(role="user", content="Hello"):
    msg = MagicMock(spec=AIChatMessage)
    msg.id = uuid4()
    msg.field_id = uuid4()
    msg.thread_id = uuid4()
    msg.role = role
    msg.content = content
    msg.status = "completed"
    msg.created_at = datetime.now(timezone.utc)
    msg.idempotency_key = None
    msg.reply_to_message_id = None
    return msg


def _configure_db_query(mock_db, messages):
    mock_query = MagicMock()
    mock_filtered = MagicMock()
    mock_ordered = MagicMock()
    mock_limited = MagicMock()
    mock_limited.all.return_value = messages
    mock_ordered.limit.return_value = mock_limited
    mock_filtered.order_by.return_value = mock_ordered
    mock_query.filter.return_value = mock_filtered

    att_query = MagicMock()
    att_filtered = MagicMock()
    att_ordered = MagicMock()
    att_ordered.all.return_value = []
    att_filtered.order_by.return_value = att_ordered
    att_query.filter.return_value = att_filtered

    def side_effect(model):
        if model == AIChatMessage:
            return mock_query
        if model == ChatAttachment:
            return att_query
        return MagicMock()

    mock_db.query.side_effect = side_effect
    return mock_query, mock_filtered


def test_get_history_returns_paginated_messages(client, mock_db):
    field_id = uuid4()
    messages = [_make_message("model", "Hello!"), _make_message("user", "Hi")]

    with patch("app.api.chat.owned_field"):
        _configure_db_query(mock_db, messages)
        response = client.get(f"/api/fields/{field_id}/chat")

    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) == 2
    assert data[0]["role"] == "user"
    assert data[0]["content"] == "Hi"
    assert data[1]["role"] == "model"
    assert data[1]["content"] == "Hello!"


def test_get_history_with_before_parameter(client, mock_db):
    field_id = uuid4()
    before = datetime.now(timezone.utc)
    messages = [_make_message("user", "Older message")]

    with patch("app.api.chat.owned_field"):
        mock_query, mock_field_filtered = _configure_db_query(mock_db, messages)
        mock_before_filtered = MagicMock()
        mock_ordered = MagicMock()
        mock_limited = MagicMock()
        mock_ordered.limit.return_value = mock_limited
        mock_limited.all.return_value = messages
        mock_before_filtered.order_by.return_value = mock_ordered
        mock_field_filtered.filter.return_value = mock_before_filtered

        response = client.get(
            f"/api/fields/{field_id}/chat",
            params={"before": before.isoformat()},
        )

    assert response.status_code == 200
    mock_field_filtered.filter.assert_called_once()
    call_arg = mock_field_filtered.filter.call_args[0][0]
    assert "created_at" in str(call_arg)
    data = response.json()
    assert len(data) == 1
    assert data[0]["content"] == "Older message"


def test_get_attachment_with_valid_attachment(client, mock_db):
    field_id = uuid4()
    attachment_id = uuid4()
    attachment = MagicMock(spec=ChatAttachment)
    attachment.id = attachment_id
    attachment.field_id = field_id
    attachment.mime_type = "image/jpeg"
    attachment.storage_key = "test-storage-key"
    attachment.byte_size = 1024
    attachment.width = 800
    attachment.height = 600
    attachment.sha256 = "abc123"

    with patch("app.api.chat.owned_field"):
        mock_query = MagicMock()
        mock_query.join.return_value.filter.return_value.first.return_value = attachment

        def side_effect(model):
            if model == ChatAttachment:
                return mock_query
            return MagicMock()

        mock_db.query.side_effect = side_effect

        mock_storage = MagicMock()
        mock_storage.read.return_value = b"fake-image-bytes"
        with patch("app.api.chat.get_chat_media_storage", return_value=mock_storage):
            response = client.get(f"/api/fields/{field_id}/chat/attachments/{attachment_id}")

    assert response.status_code == 200
    assert response.headers["content-type"] == "image/jpeg"
    assert response.content == b"fake-image-bytes"


def test_get_attachment_with_nonexistent_attachment(client, mock_db):
    field_id = uuid4()
    attachment_id = uuid4()

    with patch("app.api.chat.owned_field"):
        mock_query = MagicMock()
        mock_filtered = MagicMock()
        mock_query.filter.return_value = mock_filtered
        mock_filtered.first.return_value = None

        def side_effect(model):
            if model == ChatAttachment:
                return mock_query
            return MagicMock()

        mock_db.query.side_effect = side_effect

        response = client.get(f"/api/fields/{field_id}/chat/attachments/{attachment_id}")

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "attachment_not_found"
