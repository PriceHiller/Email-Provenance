from datetime import datetime
from typing import Any

from app.scrape import DkimRecord, scrape_dkim_selectors

from aws_lambda_powertools import Logger
from aws_lambda_powertools.utilities.typing import LambdaContext
from aws_lambda_powertools.logging.buffer import LoggerBufferConfig

import boto3

log = Logger(service="ekim", buffer_config=LoggerBufferConfig())


async def handle_domain_scrape(domain: str, dynamo_table: str, _ctx: LambdaContext):
    try:
        log.info(f"Scraping dkim keys for domain: '{domain}'", domain=domain)
        scraped_keys = await scrape_dkim_selectors(domain)
        records: list[DkimRecord] = [key.to_dkim_record() for key in scraped_keys]
        log.info(
            f"Finished scraping dkim keys for domain: '{domain}', scraped '{len(records)}' selectors",
            domain=domain,
            records=records,
        )
        dynamodb = boto3.client("dynamodb")
        for record in records:
            output = dynamodb.update_item(
                TableName=dynamo_table,
                Key={"domain": {"S": domain}},
                UpdateExpression="SET dkim_records = list_append(if_not_exists(dkim_records, :empty_list), :new_dkim_record), domain = :domain",
                ExpressionAttributeValues={
                    ":empty_list": {"L": []},
                    ":domain": {"S": domain},
                    ":new_dkim_record": {
                        "L": [
                            {
                                "M": {
                                    "qname": {"S": record.qname},
                                    "cname": {"S": record.cname},
                                    "value": {"S": record.value},
                                    "timestamp": {"S": datetime.now().isoformat()},
                                }
                            }
                        ]
                    },
                },
                ReturnValues="ALL_NEW",
            )
            log.debug(
                f"Added new record to dynamodb table '{dynamo_table}'", record=output
            )
        return {
            "statusCode": 200,
            "status": "success",
            "message": f"successfully scraped and stored {len(records)} new dkim records for the domain '{domain}'",
            "records": [r.to_dict() for r in records],
        }
    except Exception as e:
        log.error(e)
        return {
            "statusCode": 500,
            "status": "failed",
            "message": "failed to process request",
            "error": str(e),
        }


async def handle_domain_retrieval(domain: str, dynamo_table: str, _ctx: LambdaContext):
    log.info(f"Retreiving stored Dynamo records for domain: '{domain}'", domain=domain)
    dynamodb = boto3.client("dynamodb")
    out = dynamodb.get_item(
        TableName=dynamo_table,
        Key={"domain": {"S": domain}},
    )
    dkim_records: list[dict[str, str]] = []
    for val in out.values():
        records: dict[str, Any] = val.get("dkim_records")  # pyright: ignore[reportUnknownMemberType, reportAttributeAccessIssue, reportUnknownVariableType]
        if not records:
            continue
        for record in records["L"]:  # pyright: ignore[reportUnknownVariableType]
            rec: dict[str, Any] = record["M"]  # pyright: ignore[reportUnknownVariableType]

            drec = DkimRecord(
                qname=rec["cname"]["S"],  # pyright: ignore[reportUnknownArgumentType]
                cname=rec["cname"]["S"],  # pyright: ignore[reportUnknownArgumentType]
                value=rec["value"]["S"],  # pyright: ignore[reportUnknownArgumentType]
            ).to_dict()
            drec["timestamp"] = rec["timestamp"]["S"]
            dkim_records.append(drec)

    return {
        "statusCode": 200,
        "status": "success",
        "message": f"found {len(dkim_records)} dkim records for '{domain}'",
        "records": dkim_records,
    }


async def handle_rescrape(dynamo_table: str, _ctx: LambdaContext):
    dynamodb = boto3.client("dynamodb")
    domains_scraped = 0
    for values in dynamodb.scan(TableName=dynamo_table).values():
        if not isinstance(values, list):
            continue

        for item in values:  # pyright: ignore[reportUnknownVariableType]
            domain_entry: dict[str, str] = item.get("domain")  # pyright: ignore[reportUnknownMemberType, reportUnknownVariableType]
            if not domain_entry:
                continue

            domain: str = domain_entry["S"]  # pyright: ignore[reportUnknownVariableType]
            _ = await handle_domain_retrieval(domain, dynamo_table, _ctx)  # pyright: ignore[reportUnknownArgumentType]
            domains_scraped += 1
    return {
        "statusCode": 200,
        "status": "success",
        "message": f"rescraped {domains_scraped} domains",
    }

