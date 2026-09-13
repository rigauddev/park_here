"""Versioned, localized reservation term snapshots shown before reservation creation."""

TERMS_VERSION = "reservation-terms-2026-09-v1"

_COPY = {
    "pt_BR": {
        "platform": (
            "O ParkHere facilita a descoberta, comunicação e fluxo digital da reserva. "
            "O prestador identificado executa o serviço contratado. O ParkHere mantém "
            "as obrigações próprias da plataforma conforme sua atuação e a legislação; "
            "este aceite não renuncia a direitos legais do consumidor."
        ),
        "parking": (
            "Revisei unidade, categoria da vaga, período, placa, preço, taxas, previsão "
            "de chegada, tolerância e cancelamento. O estabelecimento identificado "
            "opera o estacionamento e informa as regras de guarda e permanência; "
            "continuam válidos os direitos previstos em lei."
        ),
        "car_wash": (
            "Revisei o prestador, pacote, local, horário, preço, escopo, itens não "
            "incluídos e regras de reagendamento/cancelamento do lava-jato."
        ),
        "hotel": (
            "Revisei a acomodação, hóspedes, datas, preço total, encargos, ocupação, "
            "check-in/out, cancelamento e política de no-show da hospedagem."
        ),
        "restaurant": (
            "Revisei estabelecimento, data, horário, pessoas, sinal ou consumo mínimo, "
            "tolerância e política de no-show. A reserva não inclui itens não descritos."
        ),
        "tourism": (
            "Revisei prestador, roteiro, duração, ponto de encontro, preço, inclusões, "
            "requisitos de segurança/acessibilidade e política de clima e cancelamento."
        ),
        "transport": (
            "Revisei transportador, origem, destino, horário, passageiros, bagagem, "
            "preço e regras de atraso e cancelamento."
        ),
    },
    "en": {
        "platform": (
            "ParkHere facilitates discovery, communication and the digital booking flow. "
            "The identified provider performs the booked service. ParkHere remains "
            "responsible for its own platform duties as required by law; this acceptance "
            "does not waive consumer rights."
        ),
        "parking": (
            "I reviewed the location, parking-space category, period, vehicle plate, "
            "price, fees, arrival estimate, grace period and cancellation terms. The "
            "identified business operates the parking service; statutory rights remain."
        ),
        "car_wash": (
            "I reviewed the provider, package, location, time, price, scope, exclusions "
            "and rescheduling/cancellation rules for the car wash."
        ),
        "hotel": (
            "I reviewed the accommodation, guests, dates, total price, fees, occupancy, "
            "check-in/out, cancellation and no-show terms."
        ),
        "restaurant": (
            "I reviewed the restaurant, date, time, party size, deposit or minimum spend, "
            "grace period and no-show terms. Unlisted items are not included."
        ),
        "tourism": (
            "I reviewed the provider, itinerary, duration, meeting point, price, "
            "inclusions, safety/accessibility requirements and weather/cancellation terms."
        ),
        "transport": (
            "I reviewed the carrier, origin, destination, time, passengers, luggage, "
            "price and delay/cancellation rules."
        ),
    },
}

_SERVICE_KIND = {
    "car_wash": "car_wash",
    "tour_guide": "tourism",
    "guide": "tourism",
    "tourism": "tourism",
    "hotel": "hotel",
    "restaurant": "restaurant",
    "transport": "transport",
}


def build_terms_snapshot(service_codes: list[str], locale: str) -> list[dict[str, str]]:
    language = "en" if locale == "en" else "pt_BR"
    copy = _COPY[language]
    service_kinds = ["parking"]
    for code in service_codes:
        kind = _SERVICE_KIND.get(code)
        if kind and kind not in service_kinds:
            service_kinds.append(kind)
    return [
        {"service_type": "platform", "version": TERMS_VERSION, "text": copy["platform"]},
        *[
            {"service_type": kind, "version": TERMS_VERSION, "text": copy[kind]}
            for kind in service_kinds
        ],
    ]
