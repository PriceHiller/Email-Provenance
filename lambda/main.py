from typing import Any
import ekim.handler

from aws_lambda_powertools import Logger
from aws_lambda_powertools.utilities.typing import LambdaContext
from aws_lambda_powertools.logging.buffer import LoggerBufferConfig


logger = Logger(buffer_config=LoggerBufferConfig())


def handler(event: dict[str, Any], ctx: LambdaContext):
    domain = event["domain"]
    return ekim.handler.handler(domain, ctx)


if __name__ == "__main__":
    res = handler({"domain": "pricehiller.com"}, None)  # pyright: ignore[reportArgumentType]
    print(res)
