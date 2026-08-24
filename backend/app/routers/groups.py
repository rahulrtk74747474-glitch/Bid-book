from __future__ import annotations

import secrets
from uuid import UUID

from fastapi import APIRouter, HTTPException
from sqlalchemy import func, select

from ..deps import CurrentUser, Db
from ..models import AuditLog, Group, GroupMember, GroupProposal, GroupRole, GroupVote, ProposalStatus, ServiceRequest, VoteChoice
from ..schemas import GroupCreate, GroupJoin, GroupOut, MemberOut, ProposalCreate, ProposalOut, ProposalSummary, RequestOut, VoteOut, VoteUpsert

router = APIRouter(prefix="/groups", tags=["groups"])


def _invite_code() -> str:
    return secrets.token_hex(4).upper()


async def _membership(db: Db, group_id: UUID, user_id: UUID) -> GroupMember | None:
    result = await db.execute(
        select(GroupMember).where(GroupMember.group_id == group_id, GroupMember.user_id == user_id)
    )
    return result.scalar_one_or_none()


async def _require_member(db: Db, group_id: UUID, user_id: UUID) -> GroupMember:
    member = await _membership(db, group_id, user_id)
    if member is None:
        raise HTTPException(status_code=403, detail="Group membership required")
    return member


async def _require_admin(db: Db, group_id: UUID, user_id: UUID) -> GroupMember:
    member = await _require_member(db, group_id, user_id)
    if member.role not in {GroupRole.owner, GroupRole.admin}:
        raise HTTPException(status_code=403, detail="Group admin permission required")
    return member


@router.post("", response_model=GroupOut, status_code=201)
async def create_group(payload: GroupCreate, db: Db, user: CurrentUser) -> GroupOut:
    group = Group(
        name=payload.name,
        area=payload.area,
        owner_user_id=user.id,
        invite_code=_invite_code(),
    )
    db.add(group)
    await db.flush()
    db.add(GroupMember(group_id=group.id, user_id=user.id, role=GroupRole.owner))
    db.add(AuditLog(actor_user_id=user.id, action="group.created", entity_type="group", entity_id=str(group.id)))
    await db.commit()
    await db.refresh(group)
    return GroupOut.model_validate(group)


@router.get("", response_model=list[GroupOut])
async def my_groups(db: Db, user: CurrentUser) -> list[GroupOut]:
    result = await db.execute(
        select(Group)
        .join(GroupMember, GroupMember.group_id == Group.id)
        .where(GroupMember.user_id == user.id)
        .order_by(Group.created_at.desc())
    )
    return [GroupOut.model_validate(item) for item in result.scalars().all()]


@router.post("/join", response_model=MemberOut, status_code=201)
async def join_group(payload: GroupJoin, db: Db, user: CurrentUser) -> MemberOut:
    result = await db.execute(select(Group).where(Group.invite_code == payload.invite_code.upper()))
    group = result.scalar_one_or_none()
    if group is None:
        raise HTTPException(status_code=404, detail="Invite code not found")
    existing = await _membership(db, group.id, user.id)
    if existing:
        return MemberOut.model_validate(existing)
    member = GroupMember(group_id=group.id, user_id=user.id, role=GroupRole.member)
    db.add(member)
    await db.commit()
    await db.refresh(member)
    return MemberOut.model_validate(member)


@router.post("/{group_id}/proposals", response_model=ProposalOut, status_code=201)
async def create_proposal(group_id: UUID, payload: ProposalCreate, db: Db, user: CurrentUser) -> ProposalOut:
    await _require_admin(db, group_id, user.id)
    proposal = GroupProposal(group_id=group_id, created_by_user_id=user.id, **payload.model_dump())
    db.add(proposal)
    await db.commit()
    await db.refresh(proposal)
    return ProposalOut.model_validate(proposal)


@router.get("/{group_id}/proposals", response_model=list[ProposalOut])
async def list_proposals(group_id: UUID, db: Db, user: CurrentUser) -> list[ProposalOut]:
    await _require_member(db, group_id, user.id)
    result = await db.execute(
        select(GroupProposal).where(GroupProposal.group_id == group_id).order_by(GroupProposal.created_at.desc())
    )
    return [ProposalOut.model_validate(item) for item in result.scalars().all()]


@router.put("/{group_id}/proposals/{proposal_id}/vote", response_model=VoteOut)
async def vote(
    group_id: UUID,
    proposal_id: UUID,
    payload: VoteUpsert,
    db: Db,
    user: CurrentUser,
) -> VoteOut:
    await _require_member(db, group_id, user.id)
    proposal = await db.get(GroupProposal, proposal_id)
    if proposal is None or proposal.group_id != group_id:
        raise HTTPException(status_code=404, detail="Proposal not found")
    if proposal.status != ProposalStatus.voting:
        raise HTTPException(status_code=409, detail="Voting is closed")

    result = await db.execute(
        select(GroupVote).where(GroupVote.proposal_id == proposal_id, GroupVote.user_id == user.id)
    )
    existing = result.scalar_one_or_none()
    if existing is None:
        existing = GroupVote(proposal_id=proposal_id, user_id=user.id, **payload.model_dump())
        db.add(existing)
    else:
        existing.choice = payload.choice
        existing.quantity = payload.quantity
    await db.commit()
    await db.refresh(existing)
    return VoteOut.model_validate(existing)


@router.get("/{group_id}/proposals/{proposal_id}/summary", response_model=ProposalSummary)
async def proposal_summary(group_id: UUID, proposal_id: UUID, db: Db, user: CurrentUser) -> ProposalSummary:
    await _require_member(db, group_id, user.id)
    proposal = await db.get(GroupProposal, proposal_id)
    if proposal is None or proposal.group_id != group_id:
        raise HTTPException(status_code=404, detail="Proposal not found")

    rows = await db.execute(
        select(GroupVote.choice, func.count(GroupVote.id), func.coalesce(func.sum(GroupVote.quantity), 0))
        .where(GroupVote.proposal_id == proposal_id)
        .group_by(GroupVote.choice)
    )
    counts = {choice: (int(count), int(quantity)) for choice, count, quantity in rows.all()}
    return ProposalSummary(
        accept_count=counts.get(VoteChoice.accept, (0, 0))[0],
        reject_count=counts.get(VoteChoice.reject, (0, 0))[0],
        maybe_count=counts.get(VoteChoice.maybe, (0, 0))[0],
        accepted_quantity=counts.get(VoteChoice.accept, (0, 0))[1],
    )


@router.post("/{group_id}/proposals/{proposal_id}/publish", response_model=RequestOut, status_code=201)
async def publish_proposal(group_id: UUID, proposal_id: UUID, db: Db, user: CurrentUser) -> RequestOut:
    await _require_admin(db, group_id, user.id)
    group = await db.get(Group, group_id)
    proposal = await db.get(GroupProposal, proposal_id, with_for_update=True)
    if group is None or proposal is None or proposal.group_id != group_id:
        raise HTTPException(status_code=404, detail="Proposal not found")
    if proposal.status != ProposalStatus.voting:
        raise HTTPException(status_code=409, detail="Proposal already published or closed")

    accepted = await db.execute(
        select(func.count(GroupVote.id), func.coalesce(func.sum(GroupVote.quantity), 0)).where(
            GroupVote.proposal_id == proposal.id,
            GroupVote.choice == VoteChoice.accept,
        )
    )
    accept_count, accepted_quantity = accepted.one()
    if int(accept_count) < 1:
        raise HTTPException(status_code=409, detail="At least one member must accept before publishing")

    request = ServiceRequest(
        created_by_user_id=user.id,
        group_id=group.id,
        title=proposal.title,
        category=proposal.category,
        description=f"{proposal.description}\n\nGroup accepted quantity: {int(accepted_quantity)}",
        area=group.area,
        requested_for=proposal.preferred_for,
    )
    db.add(request)
    await db.flush()
    proposal.status = ProposalStatus.published
    proposal.published_request_id = request.id
    db.add(
        AuditLog(
            actor_user_id=user.id,
            action="group.proposal_published",
            entity_type="service_request",
            entity_id=str(request.id),
            detail=f"proposal_id={proposal.id};accepted_quantity={int(accepted_quantity)}",
        )
    )
    await db.commit()
    await db.refresh(request)
    return RequestOut.model_validate(request)
