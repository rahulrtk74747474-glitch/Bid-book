"""Bid&Book production baseline.

Revision ID: 0001_baseline
Revises: None
Create Date: 2026-08-25
"""

from alembic import op

from app.database import Base

# Register the full model graph before creating the baseline schema.
from app import communication_models, models, ops_models, production_models, trust_models  # noqa: F401,E402

revision = "0001_baseline"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    Base.metadata.create_all(bind=op.get_bind(), checkfirst=True)


def downgrade() -> None:
    raise RuntimeError(
        "The Bid&Book production baseline migration is intentionally non-destructive. "
        "Create an explicit forward migration instead of dropping production tables."
    )
