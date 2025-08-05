import asyncio
import json
from ekim.scrape import scrape_dkim_selectors

from aws_lambda_powertools import Logger
from aws_lambda_powertools.utilities.typing import LambdaContext
from aws_lambda_powertools.logging.buffer import LoggerBufferConfig

logger = Logger(service="ekim", buffer_config=LoggerBufferConfig())


def handler(domain: str, _ctx: LambdaContext):
    try:
        logger.info(f"Scraping dkim keys for domain: '{domain}'", domain=domain)
        records = asyncio.run(scrape_dkim_selectors(domain))
        print("=" * 80)
        for record in records:
            for rrset in record.rrsets:
                print(rrset.items)
                print(rrset.to_rdataset())
                print("^^^")
                # for k, v in rrset.items:
                #     print(">>>",v)
        print("+" * 80)
        logger.info(f"Finished scraping dkim keys for domain: '{domain}', scraped '{len(records)}' selectors", domain=domain, records=records)
        return {
            "statusCode": 200,
            "body": json.dumps({
                "status": "success",
                "message": f"successfully scraped {len(records)} dkim selectors",
                "records": records
            })
        }
    except Exception as e:
        logger.error(e)
        return {
            "statusCode": 400,
            "body": json.dumps(
                {
                    "status": "failed",
                    "message": "failed to process request",
                    "error": str(e),
                }
            ),
        }
