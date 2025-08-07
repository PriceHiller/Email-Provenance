import asyncio
import os
import app.handler

from aws_lambda_powertools import Logger
from aws_lambda_powertools.utilities.typing import LambdaContext
from aws_lambda_powertools.logging.buffer import LoggerBufferConfig

log = Logger(buffer_config=LoggerBufferConfig(), service="ekim")

try:
    DYNAMO_TABLE = os.environ["DYNAMO_TABLE"]
except KeyError:
    log.critical("No `DYNAMO_TABLE` environment variable defined!")
    exit(1)

def router(event: dict[str, str], ctx: LambdaContext):
    endpoint = event.get("endpoint")
    log.info("Received event", event=event, ctx=ctx)
    if not endpoint:
        return {
            "statusCode": 400,
            "status": "failed",
            "message": "no endpoint was specified in the event!",
        }

    match endpoint.strip().lower():
        case "scrape":
            domain = event.get("domain")
            if not domain:
                return {
                    "statusCode": 400,
                    "status": "failed",
                    "message": "no domain key was specified in the event!",
                }
            return asyncio.run(app.handler.handle_domain_scrape(domain, DYNAMO_TABLE, ctx))
        case "retrieve":
            domain = event.get("domain")
            if not domain:
                return {
                    "statusCode": 400,
                    "status": "failed",
                    "message": "no domain key was specified in the event!",
                }
            return asyncio.run(app.handler.handle_domain_retrieval(domain, DYNAMO_TABLE, ctx))
        case "rescrape":
            return asyncio.run(app.handler.handle_rescrape(DYNAMO_TABLE, ctx))
        case _:
            return {"statusCode": 404, "status": "failed", "message": f"no endpoint matched the given endpoint: '{endpoint}'"}

