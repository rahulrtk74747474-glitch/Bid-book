from datetime import UTC, datetime, timedelta

from app.security import as_utc, utcnow


def test_as_utc_accepts_sqlite_style_naive_datetime() -> None:
    naive = datetime(2026, 8, 27, 1, 0, 0)
    normalized = as_utc(naive)
    assert normalized.tzinfo is UTC
    assert normalized == datetime(2026, 8, 27, 1, 0, 0, tzinfo=UTC)
    assert normalized < utcnow() + timedelta(days=1)


def test_as_utc_preserves_instant_for_aware_datetime() -> None:
    aware = datetime(2026, 8, 27, 1, 0, 0, tzinfo=UTC)
    assert as_utc(aware) == aware
