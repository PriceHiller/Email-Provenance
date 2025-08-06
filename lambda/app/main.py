import asyncio
from typing import Any
import app.handler

from aws_lambda_powertools import Logger
from aws_lambda_powertools.utilities.typing import LambdaContext
from aws_lambda_powertools.logging.buffer import LoggerBufferConfig

log = Logger(buffer_config=LoggerBufferConfig())

def handler(event: dict[str, str], ctx: LambdaContext) -> dict[str, Any]:
    domain = event.get("domain")
    if not domain:
        return {
            "statusCode": 400,
            "status": "failed",
            "message": "no domain key was specified in the event!"
        }
    return asyncio.run(app.handler.handler(domain, ctx))


if __name__ == "__main__":
    res = handler({"domain": "pricehiller.com"}, None)  # pyright: ignore[reportArgumentType]
    print(res)
