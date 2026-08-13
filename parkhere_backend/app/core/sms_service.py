class SMSService:

    @staticmethod
    def send_sms(phone: str, message: str):
        # FUTURO: integrar com Twilio
        print(f"📲 SMS enviado para {phone}: {message}")