from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.platform_fees.models import PlatformFee


@dataclass
class PlatformFeeLine:
    service_type: str
    base_amount: float
    fee_amount: float
    fee_mode: str
    fixed_amount: float
    percentage: float

    def to_dict(self) -> dict:
        return {
            "service_type": self.service_type,
            "base_amount": self.base_amount,
            "fee_amount": self.fee_amount,
            "fee_mode": self.fee_mode,
            "fixed_amount": self.fixed_amount,
            "percentage": self.percentage,
        }


class PlatformFeeService:
    @staticmethod
    async def calculate_lines(
        db: AsyncSession,
        amounts_by_service_type: dict[str, float],
    ) -> list[PlatformFeeLine]:
        if not amounts_by_service_type:
            return []

        result = await db.execute(
            select(PlatformFee).where(
                PlatformFee.service_type.in_(amounts_by_service_type.keys()),
                PlatformFee.is_active.is_(True),
            )
        )
        fees = {fee.service_type: fee for fee in result.scalars().all()}

        return [
            _calculate_line(service_type, amount, fees.get(service_type))
            for service_type, amount in amounts_by_service_type.items()
            if amount > 0 and fees.get(service_type) is not None
        ]


def _calculate_line(
    service_type: str,
    amount: float,
    fee: PlatformFee,
) -> PlatformFeeLine:
    if fee.fee_mode == "fixed":
        fee_amount = fee.fixed_amount
    elif fee.fee_mode == "percentage":
        fee_amount = amount * fee.percentage / 100
    else:
        fee_amount = fee.fixed_amount + amount * fee.percentage / 100

    fee_amount = max(fee.min_fee, fee_amount)
    if fee.max_fee is not None:
        fee_amount = min(fee.max_fee, fee_amount)

    return PlatformFeeLine(
        service_type=service_type,
        base_amount=amount,
        fee_amount=round(fee_amount, 2),
        fee_mode=fee.fee_mode,
        fixed_amount=fee.fixed_amount,
        percentage=fee.percentage,
    )
